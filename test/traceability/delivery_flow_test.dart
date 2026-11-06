import 'dart:typed_data';

import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/traceability/application/delivery_service.dart';
import 'package:auxia_mobile/traceability/domain/model/delivery.dart';
import 'package:auxia_mobile/traceability/infrastructure/persistence/sqlite_delivery_record_repository.dart';
import 'package:auxia_mobile/traceability/interfaces/pages/delivery/delivery_cubit.dart';
import 'package:auxia_mobile/traceability/interfaces/pages/delivery/delivery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../helpers/test_app.dart';

void main() {
  late Database db;
  late SqliteDeliveryRecordRepository records;
  late OutboxRepository outbox;
  late FakeDeliveryGateway gateway;
  late DeliveryService service;
  late FakeDeliveryEvidence evidence;
  late List<String> completed;

  setUp(() async {
    db = await openTestDatabase();
    records = SqliteDeliveryRecordRepository(db);
    outbox = OutboxRepository(db);
    gateway = FakeDeliveryGateway();
    service = DeliveryService(records, outbox, gateway);
    evidence = FakeDeliveryEvidence();
    completed = [];
  });

  tearDown(() => db.close());

  DeliveryCubit cubit() => DeliveryCubit(
    service,
    evidence,
    FakeLocationService(),
    order: sampleOrder,
    onRegistered: (id) async => completed.add(id),
  );

  group('DeliveryService and handler', () {
    test('saves the delivery and queues its registration', () async {
      final result = await service.register(
        order: sampleOrder,
        signaturePath: '/s.png',
        photoPath: '/p.jpg',
      );

      expect(
        result.getRight().toNullable()!.status,
        DeliveryRecordStatus.queued,
      );
      final item = (await outbox.due()).single;
      expect(item.type, deliveryOutboxType);
      expect(item.payload, {'deliveryId': sampleOrder.deliveryId});
    });

    test('nothing to deliver is refused', () async {
      final empty = DeliveryOrder(
        deliveryId: sampleOrder.deliveryId,
        zoneName: 'Z',
        brigadeName: 'B',
        lines: [sampleOrder.lines.single.withDelivered(0)],
      );

      final result = await service.register(
        order: empty,
        signaturePath: '/s.png',
        photoPath: '/p.jpg',
      );

      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    });

    test('the handler stores the hash given by the backend', () async {
      await service.register(
        order: sampleOrder,
        signaturePath: '/s.png',
        photoPath: '/p.jpg',
      );

      final result = await DeliveryRegistrationHandler(
        records,
        gateway,
      ).send((await outbox.due()).single);

      expect(result.isRight(), isTrue);
      final record = (await records.find(sampleOrder.deliveryId))!;
      expect(record.status, DeliveryRecordStatus.registered);
      expect(record.recordHash, endsWith('c91e'));
    });

    test('a refused delivery keeps the reason', () async {
      gateway.registerResult = const Left(
        ValidationFailure('La cantidad supera la del plan.', statusCode: 422),
      );
      await service.register(
        order: sampleOrder,
        signaturePath: '/s.png',
        photoPath: '/p.jpg',
      );

      await DeliveryRegistrationHandler(
        records,
        gateway,
      ).send((await outbox.due()).single);

      final record = (await records.find(sampleOrder.deliveryId))!;
      expect(record.status, DeliveryRecordStatus.rejected);
      expect(record.rejection, 'La cantidad supera la del plan.');
    });

    test('a lost signal keeps the delivery queued', () async {
      gateway.registerResult = const Left(NetworkFailure());
      await service.register(
        order: sampleOrder,
        signaturePath: '/s.png',
        photoPath: '/p.jpg',
      );

      await DeliveryRegistrationHandler(
        records,
        gateway,
      ).send((await outbox.due()).single);

      expect(
        (await records.find(sampleOrder.deliveryId))!.status,
        DeliveryRecordStatus.queued,
      );
    });

    test('the anchoring is read until the hash is on Blockchain', () async {
      await service.register(
        order: sampleOrder,
        signaturePath: '/s.png',
        photoPath: '/p.jpg',
      );
      await DeliveryRegistrationHandler(
        records,
        gateway,
      ).send((await outbox.due()).single);

      final result = await service.refreshIntegrity(sampleOrder.deliveryId);

      final record = result.getRight().toNullable()!;
      expect(record.status, DeliveryRecordStatus.anchored);
      expect(record.transactionHash, startsWith('0x7f3a'));
    });
  });

  group('DeliveryCubit (A_08)', () {
    test('a wrong QR does not open the evidence step', () async {
      final delivery = cubit()..scanned('8b7c0000-0000-4000-8000-000000000000');

      expect(delivery.state.step, DeliveryStep.scan);
      expect(delivery.state.wrongCode, isTrue);
      await delivery.close();
    });

    test('evidence must be complete before registering', () async {
      final delivery = cubit()..scanned(sampleOrder.deliveryId);
      expect(delivery.state.step, DeliveryStep.evidence);

      await delivery.submit();
      expect(delivery.state.record, isNull);

      await delivery.signed(Uint8List.fromList([1]));
      await delivery.takePhoto();
      expect(delivery.state.evidenceComplete, isTrue);

      await delivery.submit();
      expect(delivery.state.step, DeliveryStep.blockchain);
      expect(delivery.state.record!.location, isNotNull);
      expect(completed, [sampleOrder.deliveryId]);
      await delivery.close();
    });

    test('quantities can be lowered, never raised above the plan', () async {
      final delivery = cubit()
        ..scanned(sampleOrder.deliveryId)
        ..changeQuantity('r1', -2)
        ..changeQuantity('r1', 5);

      expect(delivery.state.order.lines.single.delivered, 12);
      delivery.changeQuantity('r1', -2);
      expect(delivery.state.order.lines.single.delivered, 10);
      await delivery.close();
    });
  });

  testWidgets('A_08 goes from scan to the Blockchain seal', (tester) async {
    tester.view.physicalSize = const Size(1170, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late DeliveryCubit delivery;
    await tester.pumpWidget(
      localizedApp(
        DeliveryScreen(
          order: sampleOrder,
          createCubit: (_) => delivery = cubit(),
          onNextMission: () {},
          onOpenTransaction: (_) {},
          scannerBuilder: (onDetect) => TextButton(
            onPressed: () => onDetect(sampleOrder.deliveryId),
            child: const Text('fake-scan'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verificar entrega'), findsOneWidget);
    expect(find.text('#3F2A-91C0'), findsWidgets);
    await tester.tap(find.text('fake-scan'));
    await tester.pumpAndSettle();

    expect(find.text('1 · Escaneo ✓'), findsOneWidget);
    expect(find.text('12/12 · Kit de víveres'), findsOneWidget);

    await delivery.signed(Uint8List.fromList([1]));
    await tester.tap(find.text('Foto de recepción'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar entrega'));
    await tester.pumpAndSettle();

    expect(
      find.text('Entrega guardada · se registrará al detectar señal'),
      findsOneWidget,
    );

    await DeliveryRegistrationHandler(
      records,
      gateway,
    ).send((await outbox.due()).single);
    await delivery.refresh();
    await tester.pumpAndSettle();

    expect(find.text('Validado e Inmutable en Blockchain'), findsOneWidget);
    expect(find.text('0x7f3a…c91e'), findsOneWidget);
    expect(find.text('3 · Blockchain ✓'), findsOneWidget);
    expect(find.text('Siguiente misión'), findsOneWidget);
  });
}
