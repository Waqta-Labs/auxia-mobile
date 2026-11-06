import 'dart:async';
import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import 'outbox_item.dart';

/// SQLite table of writes waiting to reach the backend.
class OutboxRepository {
  OutboxRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final Database _db;
  final DateTime Function() _clock;
  final Uuid _uuid;
  final StreamController<void> _changes = StreamController.broadcast();

  /// Fires after every write, so screens can refresh their counters.
  Stream<void> get changes => _changes.stream;

  /// Saves a write to send as soon as possible and returns it.
  Future<OutboxItem> enqueue({
    required String type,
    required Map<String, Object?> payload,
    String? id,
  }) async {
    final now = _clock();
    final item = OutboxItem(
      id: id ?? _uuid.v4(),
      type: type,
      payload: payload,
      status: OutboxStatus.pending,
      attempts: 0,
      nextAttemptAt: now,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('outbox', _toRow(item));
    _changes.add(null);
    return item;
  }

  Future<OutboxItem?> find(String id) async {
    final rows = await _db.query('outbox', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Pending writes whose next attempt is due, oldest first.
  Future<List<OutboxItem>> due() async {
    final rows = await _db.query(
      'outbox',
      where: 'status = ? AND next_attempt_at <= ?',
      whereArgs: [OutboxStatus.pending.name, _clock().millisecondsSinceEpoch],
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Pending and in-flight writes, optionally of one type.
  Future<int> countUnsent({String? type}) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM outbox WHERE status IN (?, ?)'
      '${type == null ? '' : ' AND type = ?'}',
      [OutboxStatus.pending.name, OutboxStatus.sending.name, ?type],
    );
    return result.first['total']! as int;
  }

  Future<void> markSending(String id) =>
      _update(id, {'status': OutboxStatus.sending.name});

  Future<void> markSent(String id) =>
      _update(id, {'status': OutboxStatus.sent.name, 'last_error': null});

  Future<void> markRejected(String id, String error) =>
      _update(id, {'status': OutboxStatus.rejected.name, 'last_error': error});

  /// Puts the write back in the queue for a later attempt.
  Future<void> reschedule(
    String id, {
    required int attempts,
    required DateTime nextAttemptAt,
    String? error,
  }) => _update(id, {
    'status': OutboxStatus.pending.name,
    'attempts': attempts,
    'next_attempt_at': nextAttemptAt.millisecondsSinceEpoch,
    'last_error': error,
  });

  /// "Forzar reintento": every pending write becomes due now.
  Future<void> makeAllDue() async {
    await _db.update(
      'outbox',
      {'next_attempt_at': _clock().millisecondsSinceEpoch},
      where: 'status = ?',
      whereArgs: [OutboxStatus.pending.name],
    );
    _changes.add(null);
  }

  /// A write left in `sending` by a closed app goes back to the queue.
  Future<void> recoverInterrupted() async {
    await _db.update(
      'outbox',
      {'status': OutboxStatus.pending.name},
      where: 'status = ?',
      whereArgs: [OutboxStatus.sending.name],
    );
  }

  Future<void> _update(String id, Map<String, Object?> values) async {
    await _db.update(
      'outbox',
      {...values, 'updated_at': _clock().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changes.add(null);
  }

  static Map<String, Object?> _toRow(OutboxItem item) => {
    'id': item.id,
    'type': item.type,
    'payload': jsonEncode(item.payload),
    'status': item.status.name,
    'attempts': item.attempts,
    'next_attempt_at': item.nextAttemptAt.millisecondsSinceEpoch,
    'last_error': item.lastError,
    'created_at': item.createdAt.millisecondsSinceEpoch,
    'updated_at': item.updatedAt.millisecondsSinceEpoch,
  };

  static OutboxItem _fromRow(Map<String, Object?> row) => OutboxItem(
    id: row['id']! as String,
    type: row['type']! as String,
    payload: jsonDecode(row['payload']! as String) as Map<String, Object?>,
    status: OutboxStatus.fromName(row['status']! as String),
    attempts: row['attempts']! as int,
    nextAttemptAt: _time(row['next_attempt_at']),
    createdAt: _time(row['created_at']),
    updatedAt: _time(row['updated_at']),
    lastError: row['last_error'] as String?,
  );

  static DateTime _time(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value! as int);
}
