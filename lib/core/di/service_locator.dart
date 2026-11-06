import 'package:get_it/get_it.dart';

import '../config/app_config.dart';
import '../localization/locale_cubit.dart';
import '../network/api_client.dart';

/// Global service locator. Only `main.dart`, the router and the screens'
/// providers read from it; classes receive their dependencies by constructor.
final GetIt getIt = GetIt.instance;

Future<void> configureDependencies({AppConfig? config}) async {
  final appConfig = config ?? AppConfig.fromEnvironment();

  getIt
    ..registerSingleton<AppConfig>(appConfig)
    ..registerSingleton<LocaleCubit>(LocaleCubit())
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        config: appConfig,
        accessToken: () async => null,
        language: () => getIt<LocaleCubit>().languageTag,
      ),
    );
}
