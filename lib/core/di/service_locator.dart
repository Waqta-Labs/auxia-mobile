import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../emergencymanagement/application/citizen_report_sync.dart';
import '../../emergencymanagement/application/quick_evidence.dart';
import '../../emergencymanagement/application/sos_service.dart';
import '../../emergencymanagement/domain/repositories/citizen_report_gateway.dart';
import '../../emergencymanagement/domain/repositories/citizen_report_repository.dart';
import '../../emergencymanagement/infrastructure/api/http_citizen_report_gateway.dart';
import '../../emergencymanagement/infrastructure/device/device_quick_evidence.dart';
import '../../emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import '../../identityaccess/application/auth_service.dart';
import '../../identityaccess/application/brigade_registration_service.dart';
import '../../identityaccess/application/profile_service.dart';
import '../../identityaccess/domain/repositories/brigade_registration_gateway.dart';
import '../../identityaccess/domain/repositories/profile_repository.dart';
import '../../identityaccess/domain/repositories/session_repository.dart';
import '../../identityaccess/infrastructure/api/http_authentication_gateway.dart';
import '../../identityaccess/infrastructure/api/http_brigade_registration_gateway.dart';
import '../../identityaccess/infrastructure/device/id_card_camera.dart';
import '../../identityaccess/infrastructure/persistence/secure_profile_repository.dart';
import '../../identityaccess/infrastructure/persistence/secure_session_repository.dart';
import '../../identityaccess/interfaces/profile_cubit.dart';
import '../../networkstorage/application/storage_stats.dart';
import '../../networkstorage/infrastructure/sqlite_storage_stats.dart';
import '../../resourcemanagement/application/mission_service.dart';
import '../../resourcemanagement/domain/repositories/mission_ports.dart';
import '../../resourcemanagement/infrastructure/api/http_mission_gateway.dart';
import '../../resourcemanagement/infrastructure/device/navigation_launcher.dart';
import '../../resourcemanagement/infrastructure/persistence/sqlite_mission_cache.dart';
import '../../traceability/application/delivery_evidence.dart';
import '../../traceability/application/delivery_service.dart';
import '../../traceability/domain/repositories/delivery_ports.dart';
import '../../traceability/infrastructure/api/http_delivery_gateway.dart';
import '../../traceability/infrastructure/device/device_delivery_evidence.dart';
import '../../traceability/infrastructure/device/explorer_launcher.dart';
import '../../traceability/infrastructure/persistence/sqlite_delivery_record_repository.dart';
import '../config/app_config.dart';
import '../connectivity/connectivity_monitor.dart';
import '../database/app_database.dart';
import '../localization/locale_cubit.dart';
import '../localization/locale_store.dart';
import '../location/location_service.dart';
import '../network/api_client.dart';
import '../sync/outbox_repository.dart';
import '../sync/sync_cubit.dart';
import '../sync/sync_engine.dart';

/// Global service locator. Only `main.dart` and the router read from it;
/// classes receive their dependencies by constructor.
final GetIt getIt = GetIt.instance;

Future<void> configureDependencies({AppConfig? config}) async {
  final appConfig = config ?? AppConfig.fromEnvironment();
  const storage = FlutterSecureStorage();
  final database = await AppDatabase.openEncrypted(storage: storage);
  final localeStore = LocaleStore(database.db);
  final savedLocale = await localeStore.load();

  getIt
    ..registerSingleton<AppConfig>(appConfig)
    ..registerSingleton<LocaleCubit>(
      LocaleCubit(
        savedLocale ?? LocaleCubit.defaultLocale,
        (locale) => unawaited(localeStore.save(locale)),
      ),
    )
    ..registerSingleton<FlutterSecureStorage>(storage)
    // Offline-first: encrypted database, outbox and synchronization.
    ..registerSingleton<AppDatabase>(database)
    ..registerSingleton<OutboxRepository>(OutboxRepository(database.db))
    ..registerSingleton<ConnectivityMonitor>(ConnectivityPlusMonitor())
    ..registerLazySingleton<LocationService>(GeolocatorLocationService.new)
    ..registerLazySingleton<SyncEngine>(
      () => SyncEngine(
        outbox: getIt(),
        connectivity: getIt(),
        handlers: <OutboxHandler>[
          CitizenReportHandler(getIt(), getIt(), getIt()),
          CitizenReportDetailHandler(getIt(), getIt()),
          CitizenEvidenceHandler(getIt()),
          DeliveryRegistrationHandler(getIt(), getIt()),
          BrigadeRegistrationHandler(getIt(), getIt(), getIt()),
        ],
      ),
    )
    ..registerLazySingleton<SyncCubit>(() => SyncCubit(getIt<SyncEngine>()))
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        config: appConfig,
        accessToken: () => getIt<AuthService>().accessToken(),
        language: () => getIt<LocaleCubit>().languageTag,
      ),
    )
    // Identity Access
    ..registerLazySingleton<ProfileRepository>(
      () => SecureProfileRepository(getIt()),
    )
    ..registerLazySingleton<SessionRepository>(
      () => SecureSessionRepository(getIt()),
    )
    ..registerLazySingleton<AuthenticationGateway>(
      () => HttpAuthenticationGateway(getIt()),
    )
    ..registerLazySingleton<BrigadeRegistrationGateway>(
      () => HttpBrigadeRegistrationGateway(getIt()),
    )
    ..registerLazySingleton<ProfileService>(
      () => ProfileService(getIt(), outbox: getIt()),
    )
    ..registerLazySingleton<AuthService>(
      () => AuthService(getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<BrigadeRegistrationService>(
      () => BrigadeRegistrationService(getIt(), getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<IdCardCamera>(IdCardCamera.new)
    ..registerSingleton<ProfileCubit>(
      ProfileCubit(getIt(), getIt(), registrations: getIt()),
    )
    // Emergency Management
    ..registerLazySingleton<CitizenReportRepository>(
      () => SqliteCitizenReportRepository(database.db),
    )
    ..registerLazySingleton<CitizenReportGateway>(
      () => HttpCitizenReportGateway(getIt()),
    )
    ..registerLazySingleton<SosService>(() => SosService(getIt(), getIt()))
    ..registerLazySingleton<MyReportsService>(
      () => MyReportsService(getIt(), getIt()),
    )
    ..registerLazySingleton<QuickEvidence>(DeviceQuickEvidence.new)
    // Resource Management
    ..registerLazySingleton<MissionGateway>(() => HttpMissionGateway(getIt()))
    ..registerLazySingleton<MissionCache>(() => SqliteMissionCache(database.db))
    ..registerLazySingleton<MissionService>(
      () => MissionService(getIt(), getIt()),
    )
    ..registerLazySingleton<NavigationLauncher>(NavigationLauncher.new)
    // Traceability
    ..registerLazySingleton<DeliveryRecordRepository>(
      () => SqliteDeliveryRecordRepository(database.db),
    )
    ..registerLazySingleton<DeliveryGateway>(() => HttpDeliveryGateway(getIt()))
    ..registerLazySingleton<DeliveryService>(
      () => DeliveryService(getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<DeliveryEvidence>(DeviceDeliveryEvidence.new)
    ..registerLazySingleton<ExplorerLauncher>(ExplorerLauncher.new)
    // Red y almacenamiento
    ..registerLazySingleton<StorageStatsSource>(
      () => SqliteStorageStats(database),
    );
}
