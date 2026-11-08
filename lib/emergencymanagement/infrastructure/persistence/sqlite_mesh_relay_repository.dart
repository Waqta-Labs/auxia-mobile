import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../domain/model/mesh_packet.dart';
import '../../domain/repositories/mesh_relay_repository.dart';

/// [MeshRelayRepository] on the `mesh_relays` table of the local database.
class SqliteMeshRelayRepository implements MeshRelayRepository {
  SqliteMeshRelayRepository(this._db);

  final Database _db;

  @override
  Future<void> save(MeshRelay relay) => _db.insert('mesh_relays', {
    'id': relay.clientReportId,
    'body': jsonEncode(relay.body),
    'hops': relay.hops,
    'received_at': relay.receivedAt.millisecondsSinceEpoch,
    'uploaded': relay.uploaded ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<MeshRelay?> find(String clientReportId) async {
    final rows = await _db.query(
      'mesh_relays',
      where: 'id = ?',
      whereArgs: [clientReportId],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<MeshRelay>> pending() async {
    final rows = await _db.query(
      'mesh_relays',
      where: 'uploaded = 0',
      orderBy: 'received_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  static MeshRelay _fromRow(Map<String, Object?> row) => MeshRelay(
    clientReportId: row['id']! as String,
    body: jsonDecode(row['body']! as String) as Map<String, Object?>,
    hops: row['hops']! as int,
    receivedAt: DateTime.fromMillisecondsSinceEpoch(row['received_at']! as int),
    uploaded: row['uploaded'] == 1,
  );
}
