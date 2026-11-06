import 'dart:convert';

import '../../core/database/app_database.dart';
import '../application/storage_stats.dart';

/// Reads the figures straight from the tables of the encrypted database.
/// They are technical counters of the device, not business data, so this
/// module may count rows of any context.
class SqliteStorageStats implements StorageStatsSource {
  SqliteStorageStats(this._database);

  final AppDatabase _database;

  @override
  Future<StorageStats> read() async {
    final db = _database.db;
    Future<int> count(String sql, [List<Object?> args = const []]) async =>
        (await db.rawQuery(sql, args)).first.values.first! as int;

    var evidence = 0;
    var blockchain = 0;
    for (final row in await db.query('delivery_records', columns: ['json'])) {
      final record = jsonDecode(row['json']! as String) as Map<String, Object?>;
      switch (record['status']) {
        case 'queued':
          evidence += 2;
          blockchain++;
        case 'registered':
          blockchain++;
      }
    }

    return StorageStats(
      citizenReports: await count('SELECT COUNT(*) FROM citizen_reports'),
      pendingSync: await count(
        "SELECT COUNT(*) FROM outbox WHERE status IN ('pending', 'sending')",
      ),
      missions: await count('SELECT COUNT(*) FROM missions'),
      evidenceToUpload: evidence,
      blockchainQueue: blockchain,
      databaseBytes: await _database.sizeInBytes(),
      intact: await _database.isIntact(),
    );
  }
}
