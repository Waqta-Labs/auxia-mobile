import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/emergencymanagement/interfaces/pages/emergency_detail/emergency_detail_cubit.dart';
import 'package:auxia_mobile/emergencymanagement/interfaces/pages/emergency_detail/emergency_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late SosService service;
  late FakeQuickEvidence evidence;

  setUp(() async {
    db = await openTestDatabase();
    service = SosService(
      SqliteCitizenReportRepository(db),
      OutboxRepository(db),
    );
    evidence = FakeQuickEvidence();
  });

  tearDown(() => db.close());

  testWidgets('the audio can also be recorded with taps', (tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final report = (await tester.runAsync(
      () => service.sendSos(category: HelpCategory.medical),
    ))!.getRight().toNullable()!;
    await tester.pumpWidget(
      BlocProvider(
        create: (_) =>
            EmergencyDetailCubit(service, evidence, reportId: report.id),
        child: localizedApp(
          EmergencyDetailScreen(
            reportCode: report.code,
            onBack: () {},
            onSent: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Holding the tile is not possible for every user (screen readers,
    // motor impairments): a tap starts and another one stops.
    await tester.tap(find.text('Audio · 5 s'));
    await tester.pump();
    expect(evidence.recording, isTrue);

    await tester.tap(find.text('Audio · 5 s'));
    await tester.pumpAndSettle();
    expect(evidence.recording, isFalse);
    expect(find.text('Audio guardado'), findsOneWidget);
  });
}
