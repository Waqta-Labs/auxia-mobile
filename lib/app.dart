import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/localization/locale_cubit.dart';
import 'core/sync/sync_cubit.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme/app_theme.dart';
import 'emergencymanagement/interfaces/mesh_cubit.dart';
import 'identityaccess/interfaces/profile_cubit.dart';
import 'l10n/generated/app_localizations.dart';

/// Root widget: theme, language, app-wide state and router.
class AuxiaApp extends StatelessWidget {
  const AuxiaApp({
    super.key,
    required this.router,
    required this.localeCubit,
    required this.profileCubit,
    required this.syncCubit,
    this.meshCubit,
  });

  final GoRouter router;
  final LocaleCubit localeCubit;
  final ProfileCubit profileCubit;
  final SyncCubit syncCubit;

  /// Mesh of the phone (plan D5); off when not given.
  final MeshCubit? meshCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: localeCubit),
        BlocProvider.value(value: profileCubit),
        BlocProvider.value(value: syncCubit),
        if (meshCubit case final mesh?)
          BlocProvider.value(value: mesh)
        else
          BlocProvider(create: (_) => MeshCubit.off()),
      ],
      // "Consulta el estado al sincronizar" (plan D3): after each sync pass
      // the app asks whether the credential of A_02 was decided.
      child: BlocListener<SyncCubit, SyncState>(
        listenWhen: (previous, current) =>
            current.lastSyncAt != previous.lastSyncAt &&
            current.network.isOnline,
        listener: (_, _) => profileCubit.checkRegistration(),
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) => MaterialApp.router(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            locale: locale,
            supportedLocales: LocaleCubit.supported,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        ),
      ),
    );
  }
}
