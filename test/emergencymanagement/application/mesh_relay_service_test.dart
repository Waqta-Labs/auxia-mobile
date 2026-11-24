import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/emergencymanagement/application/mesh_relay_service.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/mesh_packet.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/api/http_citizen_report_gateway.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_mesh_relay_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late SqliteCitizenReportRepository reports;
  late SqliteMeshRelayRepository relays;
  late OutboxRepository outbox;
  late DateTime now;
  late MeshRelayService mesh;

  setUp(() async {
    db = await openTestDatabase();
    reports = SqliteCitizenReportRepository(db);
    relays = SqliteMeshRelayRepository(db);
    outbox = OutboxRepository(db);
    now = DateTime.utc(2026, 11, 8, 15);
    mesh = MeshRelayService(
      reports,
      relays,
      outbox,
      bodyOf: citizenReportBody,
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  /// SOS of another phone, sent [age] ago and relayed [hops] times.
  MeshPacket packetOf(
    String id, {
    int hops = 0,
    Duration age = const Duration(minutes: 5),
  }) => MeshPacket(
    clientReportId: id,
    body: {
      'clientReportId': id,
      'source': 'CITIZEN',
      'category': 'RESCUE',
      'text': 'SOS Rescate.',
      'reportedAt': now.subtract(age).toIso8601String().substring(0, 19),
    },
    hops: hops,
  );

  CitizenReport ownReport(String id, CitizenReportStatus status) =>
      CitizenReport(
        id: id,
        code: 'SR-0001',
        category: HelpCategory.medical,
        reportedAt: now.subtract(const Duration(minutes: 10)),
        status: status,
      );

  group('MeshPacket', () {
    test('travels as bytes and comes back the same', () {
      final packet = packetOf('a', hops: 1);

      expect(MeshPacket.decode(packet.encode()), packet);
    });

    test('anything else from a nearby phone is ignored', () {
      expect(MeshPacket.decode('hola'.codeUnits), isNull);
      expect(MeshPacket.decode('{"v":1,"id":"a"}'.codeUnits), isNull);
      // The id of the packet must be the SOS it carries.
      final other = MeshPacket(
        clientReportId: 'b',
        body: packetOf('a').body,
        hops: 0,
      );
      expect(MeshPacket.decode(other.encode()), isNull);
    });
  });

  group('MeshRelayService', () {
    test('offers the SOS of this phone that did not leave yet', () async {
      await reports.save(ownReport('mine', CitizenReportStatus.saved));
      await reports.save(ownReport('sent', CitizenReportStatus.received));

      final packets = await mesh.outgoing();

      expect(packets.map((p) => p.clientReportId), ['mine']);
      expect(packets.single.hops, 0);
      expect(packets.single.body['clientReportId'], 'mine');
    });

    test('keeps an SOS of a nearby phone and queues its upload', () async {
      expect(await mesh.receive(packetOf('theirs', hops: 1)), isTrue);

      final relay = (await relays.find('theirs'))!;
      expect(relay.hops, 2, reason: 'the phone that gave it plus this one');
      final item = (await outbox.due()).single;
      expect(item.id, 'relay-theirs');
      expect(item.type, CitizenOutboxTypes.relay);
    });

    test('passes on what it holds while hops are left', () async {
      await mesh.receive(packetOf('one', hops: 0));
      await mesh.receive(packetOf('two', hops: 2));

      final packets = await mesh.outgoing();

      // "two" already went through three phones counting this one.
      expect(packets.map((p) => (p.clientReportId, p.hops)), [('one', 1)]);
    });

    test('ignores its own SOS, repeats, old SOS and too many hops', () async {
      await reports.save(ownReport('mine', CitizenReportStatus.saved));
      await mesh.receive(packetOf('once'));

      expect(await mesh.receive(packetOf('mine')), isFalse);
      expect(await mesh.receive(packetOf('once')), isFalse);
      expect(
        await mesh.receive(packetOf('old', age: const Duration(hours: 25))),
        isFalse,
      );
      expect(await mesh.receive(packetOf('far', hops: 3)), isFalse);
      expect((await outbox.due()).map((i) => i.id), ['relay-once']);
    });
  });

  group('RelayedSosHandler', () {
    test('uploads the SOS once, with its hops', () async {
      final gateway = FakeCitizenReportGateway();
      final handler = RelayedSosHandler(relays, gateway);
      await mesh.receive(packetOf('theirs', hops: 1));
      final item = (await outbox.due()).single;

      expect((await handler.send(item)).isRight(), isTrue);
      expect(gateway.relayed.single.$2, 2);
      expect(gateway.relayed.single.$1['clientReportId'], 'theirs');
      expect((await relays.find('theirs'))!.uploaded, isTrue);
      expect(await mesh.outgoing(), isEmpty);

      await handler.send(item);
      expect(gateway.relayed, hasLength(1));
    });
  });
}
