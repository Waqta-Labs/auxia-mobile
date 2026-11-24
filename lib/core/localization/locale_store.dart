import 'dart:ui';

import 'package:sqflite_common/sqlite_api.dart';

/// Keeps the chosen language in the local database.
class LocaleStore {
  LocaleStore(this._db);

  static const String _key = 'settings.language';

  final Database _db;

  Future<Locale?> load() async {
    final rows = await _db.query(
      'key_values',
      where: 'key = ?',
      whereArgs: [_key],
    );
    if (rows.isEmpty) return null;
    return Locale(rows.first['value']! as String);
  }

  Future<void> save(Locale locale) => _db.insert('key_values', {
    'key': _key,
    'value': locale.languageCode,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
