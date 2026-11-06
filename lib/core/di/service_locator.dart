import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../identityaccess/application/auth_service.dart';
import '../../identityaccess/application/profile_service.dart';
import '../../identityaccess/domain/repositories/profile_repository.dart';
import '../../identityaccess/domain/repositories/session_repository.dart';
import '../../identityaccess/infrastructure/api/http_authentication_gateway.dart';
import '../../identityaccess/infrastructure/device/id_card_camera.dart';
import '../../identityaccess/infrastructure/persistence/secure_profile_repository.dart';
import '../../identityaccess/infrastructure/persistence/secure_session_repository.dart';
import '../../identityaccess/interfaces/profile_cubit.dart';
import '../config/app_config.dart';
import '../connectivity/connectivity_monitor.dart';
import '../database/app_database.dart';
import '../localization/locale_cubit.dart';
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

  getIt
    ..registerSingleton<AppConfig>(appConfig)
    ..registerSingleton<LocaleCubit>(LocaleCubit())
    ..registerSingleton<FlutterSecureStorage>(storage)
    // Offline-first: encrypted database, outbox and synchronization.
    ..registerSingleton<AppDatabase>(database)
    ..registerSingleton<OutboxRepository>(OutboxRepository(database.db))
    ..registerSingleton<ConnectivityMonitor>(ConnectivityPlusMonitor())
    ..registerLazySingleton<SyncEngine>(
      () => SyncEngine(
        outbox: getIt(),
        connectivity: getIt(),
        handlers: const <OutboxHandler>[],
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
    ..registerLazySingleton<ProfileService>(() => ProfileService(getIt()))
    ..registerLazySingleton<AuthService>(
      () => AuthService(getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<IdCardCamera>(IdCardCamera.new)
    ..registerSingleton<ProfileCubit>(ProfileCubit(getIt(), getIt()));
}
