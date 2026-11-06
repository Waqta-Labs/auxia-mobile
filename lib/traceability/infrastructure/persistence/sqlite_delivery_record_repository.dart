import 'dart:async';
import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../../shared/domain/geo_point.dart';
import '../../domain/model/delivery.dart';
import '../../domain/repositories/delivery_ports.dart';

/// Deliveries registered from the device (table `delivery_records`).
class SqliteDeliveryRecordRepository implements DeliveryRecordRepository {
  SqliteDeliveryRecordRepository(this._db);

  final Database _db;
  final StreamController<void> _changes = StreamController.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> save(DeliveryRecord record) async {
    await _db.insert('delivery_records', {
      'id': record.deliveryId,
      'json': jsonEncode(deliveryRecordToJson(record)),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changes.add(null);
  }

  @override
  Future<DeliveryRecord?> find(String deliveryId) async {
    final rows = await _db.query(
      'delivery_records',
      where: 'id = ?',
      whereArgs: [deliveryId],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<DeliveryRecord>> all() async {
    final rows = await _db.query(
      'delivery_records',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  static DeliveryRecord _fromRow(Map<String, Object?> row) =>
      deliveryRecordFromJson(
        jsonDecode(row['json']! as String) as Map<String, Object?>,
      );
}

Map<String, Object?> deliveryRecordToJson(DeliveryRecord record) => {
  'order': {
    'deliveryId': record.order.deliveryId,
    'zoneName': record.order.zoneName,
    'brigadeName': record.order.brigadeName,
    'lines': [
      for (final line in record.order.lines)
        {
          'resourceId': line.resourceId,
          'name': line.name,
          'unit': line.unit,
          'planned': line.planned,
          'delivered': line.delivered,
        },
    ],
  },
  'deliveredAt': record.deliveredAt.toIso8601String(),
  'signaturePath': record.signaturePath,
  'photoPath': record.photoPath,
  'status': record.status.name,
  'location': record.location?.toJson(),
  'recordHash': record.recordHash,
  'transactionHash': record.transactionHash,
  'anchoredAt': record.anchoredAt?.toIso8601String(),
  'rejection': record.rejection,
};

DeliveryRecord deliveryRecordFromJson(Map<String, Object?> json) {
  final order = json['order']! as Map<String, Object?>;
  final anchoredAt = json['anchoredAt'] as String?;
  return DeliveryRecord(
    order: DeliveryOrder(
      deliveryId: order['deliveryId']! as String,
      zoneName: order['zoneName']! as String,
      brigadeName: order['brigadeName']! as String,
      lines: [
        for (final line in order['lines']! as List<Object?>)
          DeliveryLine(
            resourceId:
                (line! as Map<String, Object?>)['resourceId']! as String,
            name: (line as Map<String, Object?>)['name']! as String,
            unit: line['unit'] as String?,
            planned: line['planned']! as int,
            delivered: line['delivered']! as int,
          ),
      ],
    ),
    deliveredAt: DateTime.parse(json['deliveredAt']! as String),
    signaturePath: json['signaturePath']! as String,
    photoPath: json['photoPath']! as String,
    status: DeliveryRecordStatus.values.byName(json['status']! as String),
    location: GeoPoint.fromJson(json['location']),
    recordHash: json['recordHash'] as String?,
    transactionHash: json['transactionHash'] as String?,
    anchoredAt: anchoredAt == null ? null : DateTime.parse(anchoredAt),
    rejection: json['rejection'] as String?,
  );
}
