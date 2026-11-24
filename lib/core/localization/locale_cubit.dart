import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Language of the interface (report 6.1.1: Spanish by default, English as
/// i18n option for international brigades and NGOs).
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit([Locale initial = defaultLocale, this.onChanged])
    : super(_supportedOrDefault(initial));

  static const Locale defaultLocale = Locale('es');
  static const List<Locale> supported = [Locale('es'), Locale('en')];

  /// Persists the choice so the app opens in the same language.
  final void Function(Locale locale)? onChanged;

  void change(Locale locale) {
    final match = _supportedOrDefault(locale);
    emit(match);
    onChanged?.call(match);
  }

  /// Language tag sent to the API in `Accept-Language`.
  String get languageTag => state.languageCode;

  static Locale _supportedOrDefault(Locale locale) => supported.firstWhere(
    (candidate) => candidate.languageCode == locale.languageCode,
    orElse: () => defaultLocale,
  );
}
