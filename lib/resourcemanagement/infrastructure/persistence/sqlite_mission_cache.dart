import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../../shared/domain/geo_point.dart';
import '../../domain/model/mission.dart';
import '../../domain/repositories/mission_ports.dart';

/// Missions kept in the encrypted database so the brigadist can work
/// without signal (tables `missions` and `key_values`).
class SqliteMissionCache implements MissionCache {
  SqliteMissionCache(this._db);

  static const String _brigadeKey = 'missions.brigadeName';
  static const String _refreshKey = 'missions.lastRefresh';

  final Database _db;

  @override
  Future<String?> brigadeName() => _value(_brigadeKey);

  @override
  Future<void> saveBrigadeName(String? name) => _setValue(_brigadeKey, name);

  @override
  Future<DateTime?> lastRefresh() async {
    final raw = await _value(_refreshKey);
    return raw == null ? null : DateTime.parse(raw);
  }

  @override
  Future<void> markRefreshed(DateTime when) =>
      _setValue(_refreshKey, when.toIso8601String());

  @override
  Future<List<Mission>> missions() async {
    final rows = await _db.query('missions', orderBy: 'position, updated_at');
    return [
      for (final row in rows)
        missionFromCache(
          jsonDecode(row['json']! as String) as Map<String, Object?>,
        ),
    ];
  }

  @override
  Future<void> replaceMissions(List<Mission> missions) =>
      _db.transaction((txn) async {
        await txn.delete('missions');
        for (final (index, mission) in missions.indexed) {
          await txn.insert('missions', _row(mission, index));
        }
      });

  /// Updates one mission in place, keeping its position in the list.
  @override
  Future<void> saveMission(Mission mission) async {
    final rows = await _db.query(
      'missions',
      columns: ['position'],
      where: 'id = ?',
      whereArgs: [mission.id],
    );
    final position = rows.isEmpty ? 0 : rows.first['position']! as int;
    await _db.insert(
      'missions',
      _row(mission, position),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Map<String, Object?> _row(Mission mission, int position) => {
    'id': mission.id,
    'json': jsonEncode(missionToCache(mission)),
    'position': position,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  };

  Future<String?> _value(String key) async {
    final rows = await _db.query(
      'key_values',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _setValue(String key, String? value) async {
    if (value == null) {
      await _db.delete('key_values', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await _db.insert('key_values', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

Map<String, Object?> missionToCache(Mission mission) => {
  'id': mission.id,
  'deliveryId': mission.deliveryId,
  'category': mission.category.code,
  'brigadeId': mission.brigadeId,
  'brigadeName': mission.brigadeName,
  'planId': mission.planId,
  'zoneId': mission.zoneId,
  'zoneName': mission.zoneName,
  'priority': mission.priority.name,
  'status': mission.status.name,
  'location': mission.location?.toJson(),
  'score': mission.score,
  'damage': mission.damage?.name,
  'people': {
    'peopleAffected': mission.people.peopleAffected,
    'children': mission.people.children,
    'elderly': mission.people.elderly,
    'disabled': mission.people.disabled,
  },
  'reasons': [
    for (final reason in mission.reasons)
      {'feature': reason.feature.name, 'points': reason.points},
  ],
  'items': [
    for (final item in mission.items)
      {
        'resourceId': item.resourceId,
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
      },
  ],
  'assignedAt': mission.assignedAt?.toIso8601String(),
  'completedAt': mission.completedAt?.toIso8601String(),
  'baseDistanceKm': mission.baseDistanceKm,
  'baseEtaMinutes': mission.baseEtaMinutes,
};

Mission missionFromCache(Map<String, Object?> json) {
  final people = json['people']! as Map<String, Object?>;
  final damage = json['damage'] as String?;
  final assignedAt = json['assignedAt'] as String?;
  final completedAt = json['completedAt'] as String?;
  return Mission(
    id: json['id']! as String,
    deliveryId: json['deliveryId'] as String?,
    category: MissionCategory.fromCode(json['category'] as String?),
    brigadeId: json['brigadeId']! as String,
    brigadeName: json['brigadeName']! as String,
    planId: json['planId']! as String,
    zoneId: json['zoneId']! as String,
    zoneName: json['zoneName']! as String,
    priority: PriorityLevel.values.byName(json['priority']! as String),
    status: MissionStatus.values.byName(json['status']! as String),
    location: GeoPoint.fromJson(json['location']),
    score: (json['score'] as num?)?.toDouble(),
    damage: damage == null ? null : DamageLevel.values.byName(damage),
    people: ZonePeople(
      peopleAffected: people['peopleAffected']! as int,
      children: people['children']! as int,
      elderly: people['elderly']! as int,
      disabled: people['disabled']! as int,
    ),
    reasons: [
      for (final reason in json['reasons']! as List<Object?>)
        ScoreReason(
          ScoreFeature.values.byName(
            (reason! as Map<String, Object?>)['feature']! as String,
          ),
          ((reason as Map<String, Object?>)['points']! as num).toDouble(),
        ),
    ],
    items: [
      for (final item in json['items']! as List<Object?>)
        MissionItem(
          resourceId: (item! as Map<String, Object?>)['resourceId']! as String,
          name: (item as Map<String, Object?>)['name']! as String,
          quantity: item['quantity']! as int,
          unit: item['unit'] as String?,
        ),
    ],
    assignedAt: assignedAt == null ? null : DateTime.parse(assignedAt),
    completedAt: completedAt == null ? null : DateTime.parse(completedAt),
    baseDistanceKm: (json['baseDistanceKm'] as num?)?.toDouble(),
    baseEtaMinutes: (json['baseEtaMinutes'] as num?)?.toInt(),
  );
}
