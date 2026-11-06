import 'dart:io';

import 'package:auxia_mobile/app.dart';
import 'package:auxia_mobile/core/config/app_config.dart';
import 'package:auxia_mobile/core/database/app_database.dart';
import 'package:auxia_mobile/core/di/service_locator.dart';
import 'package:auxia_mobile/core/localization/locale_cubit.dart';
import 'package:auxia_mobile/core/location/location_service.dart';
import 'package:auxia_mobile/core/maps/offline_tile_store.dart';
import 'package:auxia_mobile/core/routing/app_router.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/core/sync/sync_cubit.dart';
import 'package:auxia_mobile/emergencymanagement/application/citizen_report_sync.dart';
import 'package:auxia_mobile/emergencymanagement/application/quick_evidence.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/identityaccess/application/auth_service.dart';
import 'package:auxia_mobile/identityaccess/application/profile_service.dart';
import 'package:auxia_mobile/identityaccess/infrastructure/device/id_card_camera.dart';
import 'package:auxia_mobile/identityaccess/interfaces/profile_cubit.dart';
import 'package:auxia_mobile/networkstorage/application/offline_maps_service.dart';
import 'package:auxia_mobile/networkstorage/application/storage_stats.dart';
import 'package:auxia_mobile/networkstorage/infrastructure/sqlite_storage_stats.dart';
import 'package:auxia_mobile/resourcemanagement/application/mission_service.dart';
import 'package:auxia_mobile/resourcemanagement/infrastructure/device/navigation_launcher.dart';
import 'package:auxia_mobile/resourcemanagement/infrastructure/persistence/sqlite_mission_cache.dart';
import 'package:auxia_mobile/traceability/application/delivery_evidence.dart';
import 'package:auxia_mobile/traceability/application/delivery_service.dart';
import 'package:auxia_mobile/traceability/infrastructure/device/explorer_launcher.dart';
import 'package:auxia_mobile/traceability/infrastructure/persistence/sqlite_delivery_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'test_app.dart';

class _FakeCamera extends Mock implements IdCardCamera {}

/// The whole app over an in-memory database and fake device and backend.
class AppHarness {
  AppHarness._();

  late final InMemoryProfileRepository profiles;
  late final InMemorySessionRepository sessions;
  late final FakeAuthenticationGateway authGateway;
  late final FakeMissionGateway missionGateway;
  late final LocaleCubit localeCubit;
  late final ProfileCubit profileCubit;

  static Future<AppHarness> create() async {
    await getIt.reset();
    final harness = AppHarness._();
    final db = await openTestDatabase();
    final citizenReports = SqliteCitizenReportRepository(db);
    final outbox = OutboxRepository(db);
    harness
      ..profiles = InMemoryProfileRepository()
      ..sessions = InMemorySessionRepository()
      ..authGateway = FakeAuthenticationGateway()
      ..missionGateway = FakeMissionGateway()
      ..localeCubit = LocaleCubit();
    final profileService = ProfileService(harness.profiles);
    final auth = AuthService(
      harness.authGateway,
      harness.sessions,
      harness.profiles,
    );
    harness.profileCubit = ProfileCubit(profileService, auth);

    getIt
      ..registerSingleton<AppConfig>(
        const AppConfig(
          apiBaseUrl: 'https://api.test',
          mapTileUrlTemplate: null,
        ),
      )
      ..registerSingleton<ProfileService>(profileService)
      ..registerSingleton<AuthService>(auth)
      ..registerSingleton<IdCardCamera>(_FakeCamera())
      ..registerSingleton<SyncCubit>(SyncCubit(FakeSyncController()))
      ..registerSingleton<LocationService>(FakeLocationService())
      ..registerSingleton<OutboxRepository>(outbox)
      ..registerSingleton<SosService>(SosService(citizenReports, outbox))
      ..registerSingleton<QuickEvidence>(FakeQuickEvidence())
      ..registerSingleton<MyReportsService>(
        MyReportsService(citizenReports, FakeCitizenReportGateway()),
      )
      ..registerSingleton<MissionService>(
        MissionService(harness.missionGateway, SqliteMissionCache(db)),
      )
      ..registerSingleton<NavigationLauncher>(NavigationLauncher())
      ..registerSingleton<DeliveryService>(
        DeliveryService(
          SqliteDeliveryRecordRepository(db),
          outbox,
          FakeDeliveryGateway(),
        ),
      )
      ..registerSingleton<DeliveryEvidence>(FakeDeliveryEvidence())
      ..registerSingleton<ExplorerLauncher>(ExplorerLauncher())
      ..registerSingleton<StorageStatsSource>(
        SqliteStorageStats(AppDatabase(db)),
      )
      ..registerSingleton<OfflineMapsService>(
        OfflineMapsService(
          OfflineTileStore(
            directory: Directory.systemTemp.createTempSync('auxia_'),
            urlTemplate: 'x/{z}/{x}/{y}',
          ),
        ),
      );
    return harness;
  }

  /// Pumps the app on a phone of [size] logical pixels.
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      AuxiaApp(
        router: createAppRouter(profileCubit: profileCubit),
        localeCubit: localeCubit,
        profileCubit: profileCubit,
        syncCubit: SyncCubit(FakeSyncController()),
      ),
    );
    await profileCubit.load();
    await tester.pumpAndSettle();
  }
}
