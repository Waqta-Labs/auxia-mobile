import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/localization/locale_cubit.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

/// Root widget: theme, language and router.
class AuxiaApp extends StatelessWidget {
  const AuxiaApp({super.key, required this.router, required this.localeCubit});

  final GoRouter router;
  final LocaleCubit localeCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: localeCubit,
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
    );
  }
}
