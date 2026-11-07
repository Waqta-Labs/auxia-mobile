import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// Local database of the app (report 4.1 R-02: "cola local SQLite").
///
/// It is encrypted with SQLCipher; the key is generated on the first launch
/// and kept in the Keystore / Keychain. Every feature adds its tables through
/// a new entry in [migrations], so existing installs upgrade in place.
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static const String fileName = 'auxia.db';

  /// SQL statements of each schema version, applied in order.
  static const List<List<String>> migrations = [
    // Version 1: outbox of writes waiting to reach the backend.
    [
      '''
      CREATE TABLE outbox (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER NOT NULL,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
      ''',
      'CREATE INDEX outbox_due ON outbox (status, next_attempt_at)',
    ],
    // Version 2: SOS reports of the citizen (A_03 to A_05).
    [
      '''
      CREATE TABLE citizen_reports (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        category TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        reported_at INTEGER NOT NULL,
        children INTEGER NOT NULL DEFAULT 0,
        elderly INTEGER NOT NULL DEFAULT 0,
        injured INTEGER NOT NULL DEFAULT 0,
        access_conditions TEXT NOT NULL DEFAULT '',
        audio_path TEXT,
        photo_path TEXT,
        status TEXT NOT NULL,
        score REAL,
        eta_minutes INTEGER
      )
      ''',
    ],
    // Version 3: missions of the brigadist cached for offline work (A_07).
    [
      '''
      CREATE TABLE missions (
        id TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
      ''',
      '''
      CREATE TABLE key_values (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''',
    ],
    // Version 4: deliveries registered from the device (A_08).
    [
      '''
      CREATE TABLE delivery_records (
        id TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
      ''',
    ],
    // Version 5: missions keep the order of /me/missions (A_07, plan D4).
    [
      'ALTER TABLE missions ADD COLUMN position INTEGER NOT NULL DEFAULT 0',
      "DELETE FROM key_values WHERE key = 'missions.myBrigadeId'",
    ],
  ];

  static int get version => migrations.length;

  /// Options shared by the device database and the in-memory test database.
  static OpenDatabaseOptions options() => OpenDatabaseOptions(
    version: version,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) => _migrate(db, 0, version),
    onUpgrade: _migrate,
  );

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var version = from; version < to; version++) {
      for (final statement in migrations[version]) {
        await db.execute(statement);
      }
    }
  }

  /// Opens the encrypted database of the device.
  static Future<AppDatabase> openEncrypted({
    required FlutterSecureStorage storage,
  }) async {
    final directory = await sqlcipher.getDatabasesPath();
    final options = AppDatabase.options();
    final db = await sqlcipher.openDatabase(
      p.join(directory, fileName),
      password: await _encryptionKey(storage),
      version: options.version,
      onConfigure: options.onConfigure,
      onCreate: options.onCreate,
      onUpgrade: options.onUpgrade,
    );
    return AppDatabase(db);
  }

  static Future<String> _encryptionKey(FlutterSecureStorage storage) async {
    const keyName = 'auxia.database.key.v1';
    final existing = await storage.read(key: keyName);
    if (existing != null) return existing;
    final random = Random.secure();
    final key = base64Url.encode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await storage.write(key: keyName, value: key);
    return key;
  }

  /// Size of the database file in bytes, for "Tamaño de BD" (A_06).
  Future<int> sizeInBytes() async {
    final pages = await db.rawQuery('PRAGMA page_count');
    final pageSize = await db.rawQuery('PRAGMA page_size');
    return _int(pages.first.values.first) * _int(pageSize.first.values.first);
  }

  /// SQLCipher on Android returns PRAGMA values as text; SQLite as integers.
  static int _int(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  /// SQLite integrity check, for "Integridad" (A_06).
  Future<bool> isIntact() async {
    final result = await db.rawQuery('PRAGMA quick_check');
    return result.first.values.first == 'ok';
  }
}
