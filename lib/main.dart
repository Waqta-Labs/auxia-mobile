import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/localization/locale_cubit.dart';
import 'core/routing/app_router.dart';
import 'core/sync/sync_cubit.dart';
import 'core/sync/sync_engine.dart';
import 'identityaccess/interfaces/profile_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  await configureDependencies();

  final profileCubit = getIt<ProfileCubit>();
  unawaited(profileCubit.load());
  unawaited(getIt<SyncEngine>().start());

  runApp(
    AuxiaApp(
      router: createAppRouter(profileCubit: profileCubit),
      localeCubit: getIt<LocaleCubit>(),
      profileCubit: profileCubit,
      syncCubit: getIt<SyncCubit>(),
    ),
  );
}

/// Inter is bundled under the SIL Open Font License, which asks to ship the
/// license with the font.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], license);
  });
}
