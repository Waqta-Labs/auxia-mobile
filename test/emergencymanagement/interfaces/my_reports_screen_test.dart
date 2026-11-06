import 'package:auxia_mobile/core/sync/sync_cubit.dart';
import 'package:auxia_mobile/emergencymanagement/application/citizen_report_sync.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/emergencymanagement/interfaces/pages/my_reports/my_reports_cubit.dart';
import 'package:auxia_mobile/emergencymanagement/interfaces/pages/my_reports/my_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late SqliteCitizenReportRepository reports;
  late FakeSyncController sync;

  setUp(() async {
    db = await openTestDatabase();
    reports = SqliteCitizenReportRepository(db);
    sync = FakeSyncController();
  });

  tearDown(() => db.close());

  CitizenReport report(
    String code,
    HelpCategory category,
    CitizenReportStatus status, {
    double? score,
    int? eta,
  }) => CitizenReport(
    id: code,
    code: code,
    category: category,
    reportedAt: DateTime.now().subtract(const Duration(minutes: 18)),
    status: status,
    score: score,
    etaMinutes: eta,
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final service = MyReportsService(reports, FakeCitizenReportGateway());
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SyncCubit(sync)),
          BlocProvider(create: (_) => MyReportsCubit(service)..start()),
        ],
        child: localizedApp(const MyReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows each report with its step and label', (tester) async {
    await reports.save(
      report('SR-0412', HelpCategory.medical, CitizenReportStatus.saved),
    );
    await reports.save(
      report('SR-0411', HelpCategory.rescue, CitizenReportStatus.transmitting),
    );
    await reports.save(
      report(
        'SR-0398',
        HelpCategory.medical,
        CitizenReportStatus.prioritized,
        score: 94,
      ),
    );
    await reports.save(
      report(
        'SR-0377',
        HelpCategory.supplies,
        CitizenReportStatus.brigadeOnTheWay,
        eta: 12,
      ),
    );

    await pump(tester);

    expect(find.text('COLA LOCAL · 4 REPORTES'), findsOneWidget);
    expect(find.text('SR-0412 · Médico'), findsOneWidget);
    expect(find.text('Guardado en dispositivo'), findsOneWidget);
    expect(find.text('Transmitiendo…'), findsOneWidget);
    expect(find.text('Priorizado por IA · 94'), findsOneWidget);
    expect(find.text('Brigada en camino · ETA 12 min'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Paso 4 de 4')), findsOneWidget);
  });

  testWidgets('offline, it shows no signal and unavailable channels', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Sin señal'), findsOneWidget);
    expect(find.bySemanticsLabel('Celular · no disponible'), findsOneWidget);
    expect(find.bySemanticsLabel('Mesh · no disponible'), findsOneWidget);
    expect(find.bySemanticsLabel('Satélite · no disponible'), findsOneWidget);
    expect(find.textContaining('Aún no enviaste reportes'), findsOneWidget);
  });

  testWidgets('forcing the retry asks the sync engine', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Forzar reintento de sincronización'));
    await tester.pumpAndSettle();

    expect(sync.retryCalls, 1);
  });

  testWidgets('a report opens its detail in a bottom sheet', (tester) async {
    await reports.save(
      report(
        'SR-0001',
        HelpCategory.rescue,
        CitizenReportStatus.saved,
      ).withDetail(const EmergencyDetail(children: 3)),
    );
    await pump(tester);

    await tester.tap(find.text('SR-0001 · Rescate'));
    await tester.pumpAndSettle();

    expect(find.text('Niños: 3'), findsOneWidget);
    expect(find.text('Sin ubicación GPS'), findsOneWidget);
  });
}
