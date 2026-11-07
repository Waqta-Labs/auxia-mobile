import 'dart:async';

import 'package:sqflite_common/sqlite_api.dart';

import '../../../shared/domain/geo_point.dart';
import '../../domain/model/citizen_report.dart';
import '../../domain/repositories/citizen_report_repository.dart';

/// Citizen reports in the encrypted database (table `citizen_reports`).
class SqliteCitizenReportRepository implements CitizenReportRepository {
  SqliteCitizenReportRepository(this._db);

  final Database _db;
  final StreamController<void> _changes = StreamController.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> save(CitizenReport report) async {
    await _db.insert(
      'citizen_reports',
      _toRow(report),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.add(null);
  }

  @override
  Future<CitizenReport?> find(String id) async {
    final rows = await _db.query(
      'citizen_reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<CitizenReport>> all() async {
    final rows = await _db.query(
      'citizen_reports',
      orderBy: 'reported_at DESC, code DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<String> nextCode() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM citizen_reports',
    );
    final next = (result.first['total']! as int) + 1;
    return 'SR-${next.toString().padLeft(4, '0')}';
  }

  static Map<String, Object?> _toRow(CitizenReport report) => {
    'id': report.id,
    'code': report.code,
    'category': report.category.code,
    'latitude': report.location?.latitude,
    'longitude': report.location?.longitude,
    'reported_at': report.reportedAt.millisecondsSinceEpoch,
    'children': report.detail.children,
    'elderly': report.detail.elderly,
    'injured': report.detail.injured,
    'access_conditions': report.detail.accessConditions
        .map((condition) => condition.code)
        .join(','),
    'audio_path': report.detail.audioPath,
    'photo_path': report.detail.photoPath,
    'status': report.status.name,
    'eta_minutes': report.etaMinutes,
  };

  static CitizenReport _fromRow(Map<String, Object?> row) {
    final latitude = row['latitude'] as double?;
    final longitude = row['longitude'] as double?;
    final conditions = (row['access_conditions']! as String)
        .split(',')
        .where((code) => code.isNotEmpty)
        .map(AccessCondition.fromCode)
        .toSet();
    return CitizenReport(
      id: row['id']! as String,
      code: row['code']! as String,
      category: HelpCategory.fromCode(row['category']! as String),
      reportedAt: DateTime.fromMillisecondsSinceEpoch(
        row['reported_at']! as int,
      ),
      status: CitizenReportStatus.fromName(row['status']! as String),
      location: latitude != null && longitude != null
          ? GeoPoint(latitude, longitude)
          : null,
      detail: EmergencyDetail(
        children: row['children']! as int,
        elderly: row['elderly']! as int,
        injured: row['injured']! as int,
        accessConditions: conditions,
        audioPath: row['audio_path'] as String?,
        photoPath: row['photo_path'] as String?,
      ),
      etaMinutes: row['eta_minutes'] as int?,
    );
  }
}
