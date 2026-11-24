import 'package:auxia_mobile/core/location/location_service.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/emergencymanagement/interfaces/pages/emergency_detail/emergency_detail_cubit.dart';
import 'package:auxia_mobile/emergencymanagement/interfaces/pages/sos/sos_cubit.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late SqliteCitizenReportRepository reports;
  late SosService service;

  setUp(() async {
    db = await openTestDatabase();
    reports = SqliteCitizenReportRepository(db);
    service = SosService(reports, OutboxRepository(db));
  });

  tearDown(() => db.close());

  group('SosCubit (A_03)', () {
    test('finds the GPS and counts the queue on start', () async {
      await service.sendSos(category: HelpCategory.medical);
      final cubit = SosCubit(service, FakeLocationService());

      await cubit.start();

      expect(cubit.state.gps, GpsStatus.fixed);
      expect(cubit.state.location, const GeoPoint(-12.0464, -77.0428));
      expect(cubit.state.queued, 1);
      await cubit.close();
    });

    test('tells when the location permission is denied', () async {
      final cubit = SosCubit(
        service,
        FakeLocationService(
          const LocationUnavailable(LocationIssue.permissionDenied),
        ),
      );

      await cubit.locate();

      expect(cubit.state.gps, GpsStatus.denied);
      await cubit.close();
    });

    test('saves the SOS with the selected category and the GPS', () async {
      final cubit = SosCubit(service, FakeLocationService());
      await cubit.locate();

      cubit.selectCategory(HelpCategory.rescue);
      await cubit.sendSos();

      final report = cubit.state.lastReport!;
      expect(report.category, HelpCategory.rescue);
      expect(report.location, const GeoPoint(-12.0464, -77.0428));
      expect(await reports.find(report.id), isNotNull);
      await cubit.close();
    });

    test('the SOS does not wait for the GPS', () async {
      final cubit = SosCubit(
        service,
        FakeLocationService(
          const LocationUnavailable(LocationIssue.unavailable),
        ),
      );

      await cubit.sendSos();

      expect(cubit.state.lastReport!.location, isNull);
      await cubit.close();
    });
  });

  group('EmergencyDetailCubit (A_04)', () {
    late CitizenReport report;
    late FakeQuickEvidence evidence;

    setUp(() async {
      report = (await service.sendSos(
        category: HelpCategory.medical,
      )).getRight().toNullable()!;
      evidence = FakeQuickEvidence();
    });

    EmergencyDetailCubit build() =>
        EmergencyDetailCubit(service, evidence, reportId: report.id);

    test('counts people without going below zero', () async {
      final cubit = build()
        ..increment(PeopleGroup.children)
        ..increment(PeopleGroup.children)
        ..increment(PeopleGroup.children)
        ..decrement(PeopleGroup.injured)
        ..increment(PeopleGroup.elderly);

      expect(cubit.state.detail.children, 3);
      expect(cubit.state.detail.injured, 0);
      expect(cubit.state.detail.elderly, 1);
      await cubit.close();
    });

    test('toggles the access conditions', () async {
      final cubit = build()
        ..toggleCondition(AccessCondition.roadBlocked)
        ..toggleCondition(AccessCondition.noDrinkingWater)
        ..toggleCondition(AccessCondition.roadBlocked);

      expect(cubit.state.detail.accessConditions, {
        AccessCondition.noDrinkingWater,
      });
      await cubit.close();
    });

    test('records audio until released and keeps the file', () async {
      final cubit = build();

      await cubit.startAudio();
      expect(cubit.state.recording, isTrue);
      await cubit.stopAudio();

      expect(cubit.state.recording, isFalse);
      expect(cubit.state.detail.audioPath, '/evidence/audio.m4a');
      await cubit.close();
    });

    test('stops the audio by itself after 5 seconds', () async {
      final cubit = EmergencyDetailCubit(
        service,
        evidence,
        reportId: report.id,
        maxAudio: const Duration(milliseconds: 10),
      );

      await cubit.startAudio();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.recording, isFalse);
      expect(evidence.recording, isFalse);
      await cubit.close();
    });

    test('explains a denied microphone', () async {
      evidence.microphoneAllowed = false;
      final cubit = build();

      await cubit.startAudio();

      expect(cubit.state.evidenceIssue, EvidenceIssue.microphone);
      expect(cubit.state.recording, isFalse);
      await cubit.close();
    });

    test('saves the detail into the SOS', () async {
      final cubit = build()
        ..increment(PeopleGroup.injured)
        ..toggleCondition(AccessCondition.damagedBuilding);
      await cubit.takePhoto();

      await cubit.submit();

      expect(cubit.state.submitted, isTrue);
      final saved = (await reports.find(report.id))!;
      expect(saved.detail.injured, 1);
      expect(saved.detail.photoPath, '/evidence/photo.jpg');
      await cubit.close();
    });
  });
}
