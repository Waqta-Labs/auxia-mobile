import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late SqliteCitizenReportRepository reports;
  late OutboxRepository outbox;
  late SosService service;
  final now = DateTime(2026, 11, 6, 9, 41);

  setUp(() async {
    db = await openTestDatabase();
    reports = SqliteCitizenReportRepository(db);
    outbox = OutboxRepository(db, clock: () => now);
    service = SosService(reports, outbox, clock: () => now);
  });

  tearDown(() => db.close());

  test('the SOS is saved on the device and queued at once', () async {
    final result = await service.sendSos(
      category: HelpCategory.rescue,
      location: const GeoPoint(-12.0464, -77.0428),
    );

    final report = result.getRight().toNullable()!;
    expect(report.code, 'SR-0001');
    expect(report.status, CitizenReportStatus.saved);
    expect(await reports.find(report.id), report);
    final queued = (await outbox.find(report.id))!;
    expect(queued.type, CitizenOutboxTypes.report);
    expect(queued.payload, {'reportId': report.id});
    expect(await service.queuedReports(), 1);
  });

  test('codes follow the order of the reports', () async {
    await service.sendSos(category: HelpCategory.medical);
    final second = await service.sendSos(category: HelpCategory.supplies);

    expect(second.getRight().toNullable()!.code, 'SR-0002');
    expect((await reports.all()).first.code, 'SR-0002');
  });

  test('a late GPS fix is added while the SOS is on the device', () async {
    final report = (await service.sendSos(
      category: HelpCategory.medical,
    )).getRight().toNullable()!;

    await service.attachLocation(report.id, const GeoPoint(-11.9, -76.7));

    expect(
      (await reports.find(report.id))!.location,
      const GeoPoint(-11.9, -76.7),
    );
  });

  test('the detail travels with an SOS that has not left yet', () async {
    final report = (await service.sendSos(
      category: HelpCategory.medical,
    )).getRight().toNullable()!;

    await service.addDetail(
      report.id,
      const EmergencyDetail(children: 3, injured: 2),
    );

    final saved = (await reports.find(report.id))!;
    expect(saved.detail.children, 3);
    expect(await outbox.countUnsent(), 1, reason: 'no second report');
  });

  test('a detail after the SOS left follows as a second report', () async {
    final report = (await service.sendSos(
      category: HelpCategory.medical,
    )).getRight().toNullable()!;
    await reports.save(report.withStatus(CitizenReportStatus.received));

    await service.addDetail(report.id, const EmergencyDetail(injured: 1));

    expect(await outbox.countUnsent(type: CitizenOutboxTypes.detail), 1);
  });

  test('an unknown report is an error, not a crash', () async {
    final result = await service.addDetail('missing', const EmergencyDetail());

    expect(result.isLeft(), isTrue);
  });

  test('the stored report keeps every field', () async {
    final report = (await service.sendSos(
      category: HelpCategory.supplies,
      location: const GeoPoint(-12, -77),
    )).getRight().toNullable()!;
    final full = report
        .withDetail(
          const EmergencyDetail(
            children: 1,
            elderly: 2,
            injured: 3,
            accessConditions: {
              AccessCondition.noCellSignal,
              AccessCondition.roadBlocked,
            },
            audioPath: '/a.m4a',
            photoPath: '/p.jpg',
          ),
        )
        .withStatus(
          CitizenReportStatus.brigadeOnTheWay,
          score: 94,
          etaMinutes: 12,
        );

    await reports.save(full);

    expect(await reports.find(report.id), full);
  });
}
