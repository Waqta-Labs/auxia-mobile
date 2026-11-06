import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Language of the interface (report 6.1.1: Spanish by default, English as
/// i18n option for international brigades and NGOs).
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit([super.initial = defaultLocale]);

  static const Locale defaultLocale = Locale('es');
  static const List<Locale> supported = [Locale('es'), Locale('en')];

  void change(Locale locale) {
    final match = supported.firstWhere(
      (candidate) => candidate.languageCode == locale.languageCode,
      orElse: () => defaultLocale,
    );
    emit(match);
  }

  /// Language tag sent to the API in `Accept-Language`.
  String get languageTag => state.languageCode;
}
