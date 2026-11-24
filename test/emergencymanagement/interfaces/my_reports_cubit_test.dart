import 'package:auxia_mobile/emergencymanagement/application/citizen_report_sync.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/domain/repositories/citizen_report_gateway.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/emergencymanagement/interfaces/pages/my_reports/my_reports_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late SqliteCitizenReportRepository reports;
  late FakeCitizenReportGateway gateway;

  setUp(() async {
    db = await openTestDatabase();
    reports = SqliteCitizenReportRepository(db);
    gateway = FakeCitizenReportGateway();
  });

  tearDown(() => db.close());

  CitizenReport report(String id, CitizenReportStatus status) => CitizenReport(
    id: id,
    code: id,
    category: HelpCategory.rescue,
    reportedAt: DateTime(2026, 11, 6, 22, 51),
    status: status,
  );

  Matcher hasStatus(String id, CitizenReportStatus status) => emitsThrough(
    predicate<MyReportsState>(
      (state) => state.reports.any(
        (report) => report.id == id && report.status == status,
      ),
    ),
  );

  void answer(String id, CitizenReportStatus status) =>
      gateway.statuses[id] = Right(RemoteReportStatus(status: status));

  test('asks for the status as soon as a report is received', () async {
    final cubit = MyReportsCubit(
      MyReportsService(reports, gateway),
      pollEvery: null,
    );
    addTearDown(cubit.close);
    await cubit.start();
    answer('SR-0002', CitizenReportStatus.prioritized);

    final prioritized = expectLater(
      cubit.stream,
      hasStatus('SR-0002', CitizenReportStatus.prioritized),
    );
    await reports.save(report('SR-0002', CitizenReportStatus.received));

    await prioritized;
  });

  test('polls while a report waits for its brigade', () async {
    await reports.save(report('SR-0001', CitizenReportStatus.received));
    answer('SR-0001', CitizenReportStatus.received);
    final cubit = MyReportsCubit(
      MyReportsService(reports, gateway),
      pollEvery: const Duration(milliseconds: 20),
    );
    addTearDown(cubit.close);
    await cubit.start();

    final onTheWay = expectLater(
      cubit.stream,
      hasStatus('SR-0001', CitizenReportStatus.brigadeOnTheWay),
    );
    answer('SR-0001', CitizenReportStatus.brigadeOnTheWay);

    await onTheWay;
  });

  test('keeps polling while a brigade is on the way', () async {
    await reports.save(report('SR-0001', CitizenReportStatus.brigadeOnTheWay));
    answer('SR-0001', CitizenReportStatus.brigadeOnTheWay);
    final cubit = MyReportsCubit(
      MyReportsService(reports, gateway),
      pollEvery: const Duration(milliseconds: 20),
    );
    addTearDown(cubit.close);
    await cubit.start();

    // The delivery was confirmed: the zone is prioritized again.
    final prioritized = expectLater(
      cubit.stream,
      hasStatus('SR-0001', CitizenReportStatus.prioritized),
    );
    answer('SR-0001', CitizenReportStatus.prioritized);

    await prioritized;
  });
}
