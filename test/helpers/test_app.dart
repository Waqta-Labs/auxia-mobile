import 'package:auxia_mobile/core/theme/app_theme.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/repositories/profile_repository.dart';
import 'package:auxia_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Wraps a screen with the AuxIA theme and the Spanish localizations.
Widget localizedApp(Widget home, {Locale locale = const Locale('es')}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

/// Profile repository kept in memory.
class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository([this.profile]);

  LocalProfile? profile;

  @override
  Future<LocalProfile?> load() async => profile;

  @override
  Future<void> save(LocalProfile profile) async => this.profile = profile;

  @override
  Future<void> clear() async => profile = null;
}
