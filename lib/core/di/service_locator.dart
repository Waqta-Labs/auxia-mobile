import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../identityaccess/application/profile_service.dart';
import '../../identityaccess/domain/repositories/profile_repository.dart';
import '../../identityaccess/infrastructure/device/id_card_camera.dart';
import '../../identityaccess/infrastructure/persistence/secure_profile_repository.dart';
import '../../identityaccess/interfaces/profile_cubit.dart';
import '../config/app_config.dart';
import '../localization/locale_cubit.dart';
import '../network/api_client.dart';

/// Global service locator. Only `main.dart` and the router read from it;
/// classes receive their dependencies by constructor.
final GetIt getIt = GetIt.instance;

Future<void> configureDependencies({AppConfig? config}) async {
  final appConfig = config ?? AppConfig.fromEnvironment();

  getIt
    ..registerSingleton<AppConfig>(appConfig)
    ..registerSingleton<LocaleCubit>(LocaleCubit())
    ..registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage())
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        config: appConfig,
        accessToken: () async => null,
        language: () => getIt<LocaleCubit>().languageTag,
      ),
    )
    // Identity Access
    ..registerLazySingleton<ProfileRepository>(
      () => SecureProfileRepository(getIt()),
    )
    ..registerLazySingleton<ProfileService>(() => ProfileService(getIt()))
    ..registerLazySingleton<IdCardCamera>(IdCardCamera.new)
    ..registerSingleton<ProfileCubit>(ProfileCubit(getIt()));
}
