import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/emergencymanagement/application/citizen_report_sync.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/domain/repositories/citizen_report_gateway.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late SqliteCitizenReportRepository reports;
  late OutboxRepository outbox;
  late SosService sos;
  late FakeCitizenReportGateway gateway;

  setUp(() async {
    db = await openTestDatabase();
    reports = SqliteCitizenReportRepository(db);
    outbox = OutboxRepository(db);
    sos = SosService(reports, outbox);
    gateway = FakeCitizenReportGateway();
  });

  tearDown(() => db.close());

  Future<CitizenReport> newSos() async => (await sos.sendSos(
    category: HelpCategory.medical,
  )).getRight().toNullable()!;

  group('CitizenReportHandler', () {
    test('a report accepted by the backend becomes received', () async {
      final report = await newSos();
      final handler = CitizenReportHandler(reports, gateway, outbox);

      final result = await handler.send((await outbox.find(report.id))!);

      expect(result.isRight(), isTrue);
      expect(
        (await reports.find(report.id))!.status,
        CitizenReportStatus.received,
      );
      expect(gateway.submitted.single.$1, report.id);
    });

    test('the detail added while waiting travels with the SOS', () async {
      final report = await newSos();
      await sos.addDetail(report.id, const EmergencyDetail(children: 2));

      await CitizenReportHandler(
        reports,
        gateway,
        outbox,
      ).send((await outbox.find(report.id))!);

      expect(gateway.submitted.single.$2, contains('2 niños'));
    });

    test('once stored, its photo and audio are queued for upload', () async {
      final report = await newSos();
      await sos.addDetail(
        report.id,
        const EmergencyDetail(photoPath: '/p.jpg', audioPath: '/a.m4a'),
      );

      await CitizenReportHandler(
        reports,
        gateway,
        outbox,
      ).send((await outbox.find(report.id))!);
      await CitizenReportHandler(
        reports,
        gateway,
        outbox,
      ).send((await outbox.find(report.id))!);

      final evidence = (await outbox.due())
          .where((item) => item.type == CitizenOutboxTypes.evidence)
          .toList();
      expect(
        evidence.map((item) => item.id),
        unorderedEquals([
          CitizenEvidenceQueue.attachmentId(report.id, EvidenceKind.photo),
          CitizenEvidenceQueue.attachmentId(report.id, EvidenceKind.audio),
        ]),
      );
    });

    test('nothing is queued for an SOS without evidence', () async {
      final report = await newSos();

      await CitizenReportHandler(
        reports,
        gateway,
        outbox,
      ).send((await outbox.find(report.id))!);

      expect(
        (await outbox.due()).where(
          (item) => item.type == CitizenOutboxTypes.evidence,
        ),
        isEmpty,
      );
    });

    test('a failed send leaves the report saved on the device', () async {
      final report = await newSos();
      gateway.submitResult = const Left(NetworkFailure());

      await CitizenReportHandler(
        reports,
        gateway,
        outbox,
      ).send((await outbox.find(report.id))!);

      expect(
        (await reports.find(report.id))!.status,
        CitizenReportStatus.saved,
      );
    });
  });

  test('a late detail is sent as a follow-up with its own id', () async {
    final report = await newSos();
    await reports.save(report.withStatus(CitizenReportStatus.received));
    await sos.addDetail(report.id, const EmergencyDetail(injured: 1));
    final item = (await outbox.due()).firstWhere(
      (item) => item.type == CitizenOutboxTypes.detail,
    );

    await CitizenReportDetailHandler(reports, gateway).send(item);

    final (id, text) = gateway.submitted.single;
    expect(id, item.id);
    expect(text, startsWith('Detalle adicional del reporte ${report.code}.'));
  });

  test(
    'a late photo alone follows as an attachment, not as a report',
    () async {
      final report = await newSos();
      await reports.save(report.withStatus(CitizenReportStatus.received));

      await sos.addDetail(
        report.id,
        const EmergencyDetail(photoPath: '/p.jpg'),
      );

      final types = (await outbox.due()).map((item) => item.type);
      expect(types, contains(CitizenOutboxTypes.evidence));
      expect(types, isNot(contains(CitizenOutboxTypes.detail)));
    },
  );

  group('CitizenEvidenceHandler', () {
    test('uploads the file with the id of its outbox item', () async {
      final report = await newSos();
      await reports.save(report.withStatus(CitizenReportStatus.received));
      await sos.addDetail(
        report.id,
        const EmergencyDetail(photoPath: '/p.jpg'),
      );
      final item = (await outbox.due()).firstWhere(
        (item) => item.type == CitizenOutboxTypes.evidence,
      );

      final result = await CitizenEvidenceHandler(
        gateway,
        exists: (_) async => true,
      ).send(item);

      expect(result.isRight(), isTrue);
      expect(gateway.uploaded.single, (report.id, item.id, '/p.jpg'));
    });

    test('a file no longer on the device leaves the queue', () async {
      final report = await newSos();
      await reports.save(report.withStatus(CitizenReportStatus.received));
      await sos.addDetail(
        report.id,
        const EmergencyDetail(audioPath: '/a.m4a'),
      );
      final item = (await outbox.due()).firstWhere(
        (item) => item.type == CitizenOutboxTypes.evidence,
      );

      final result = await CitizenEvidenceHandler(
        gateway,
        exists: (_) async => false,
      ).send(item);

      expect(result.isRight(), isTrue);
      expect(gateway.uploaded, isEmpty);
    });
  });

  group('MyReportsService', () {
    test('updates sent reports with the AI score', () async {
      final report = await newSos();
      await reports.save(report.withStatus(CitizenReportStatus.received));
      gateway.statuses[report.id] = const Right(
        RemoteReportStatus(status: CitizenReportStatus.prioritized, score: 94),
      );

      await MyReportsService(reports, gateway).refreshStatuses();

      final updated = (await reports.find(report.id))!;
      expect(updated.status, CitizenReportStatus.prioritized);
      expect(updated.score, 94);
    });

    test('updates sent reports with their stage and eta', () async {
      final report = await newSos();
      await reports.save(report.withStatus(CitizenReportStatus.received));
      gateway.statuses[report.id] = const Right(
        RemoteReportStatus(
          status: CitizenReportStatus.brigadeOnTheWay,
          etaMinutes: 12,
        ),
      );

      await MyReportsService(reports, gateway).refreshStatuses();

      final updated = (await reports.find(report.id))!;
      expect(updated.status, CitizenReportStatus.brigadeOnTheWay);
      expect(updated.etaMinutes, 12);
    });

    test('skips a report the backend does not know', () async {
      final unknown = await newSos();
      final known = await newSos();
      await reports.save(unknown.withStatus(CitizenReportStatus.received));
      await reports.save(known.withStatus(CitizenReportStatus.received));
      gateway.statuses[unknown.id] = const Left(NotFoundFailure());
      gateway.statuses[known.id] = const Right(
        RemoteReportStatus(status: CitizenReportStatus.prioritized),
      );

      await MyReportsService(reports, gateway).refreshStatuses();

      expect(
        (await reports.find(unknown.id))!.status,
        CitizenReportStatus.received,
      );
      expect(
        (await reports.find(known.id))!.status,
        CitizenReportStatus.prioritized,
      );
    });

    test('never moves a report backwards', () async {
      final report = await newSos();
      await reports.save(
        report.withStatus(CitizenReportStatus.brigadeOnTheWay, etaMinutes: 5),
      );
      gateway.statuses[report.id] = const Right(
        RemoteReportStatus(status: CitizenReportStatus.received),
      );

      await MyReportsService(reports, gateway).refreshStatuses();

      expect(
        (await reports.find(report.id))!.status,
        CitizenReportStatus.brigadeOnTheWay,
      );
    });

    test('does not ask about reports that are still on the device', () async {
      await newSos();

      await MyReportsService(reports, gateway).refreshStatuses();

      expect(gateway.statuses, isEmpty);
    });
  });
}
