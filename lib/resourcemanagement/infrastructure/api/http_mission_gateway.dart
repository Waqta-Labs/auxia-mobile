import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/domain/geo_point.dart';
import '../../domain/model/mission.dart';
import '../../domain/repositories/mission_ports.dart';

typedef Json = Map<String, Object?>;

/// [MissionGateway] over `GET /api/v1/me/missions` (plan, iteration 2): the
/// backend links the account to its brigade and builds every mission.
class HttpMissionGateway implements MissionGateway {
  HttpMissionGateway(this._client);

  final ApiClient _client;

  @override
  Future<Either<Failure, MyMissions>> myMissions() => _client.get(
    '/me/missions',
    parse: (data) => myMissionsFromJson(data! as Json),
  );
}

/// Reads a backend `LocalDateTime` (UTC without zone) or an ISO date-time.
DateTime parseBackendTime(String raw) =>
    DateTime.parse(raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z');

/// Maps `MyMissionsResource`.
MyMissions myMissionsFromJson(Json json) {
  final brigadeId = json['brigadeId'] as String?;
  final brigadeName = json['brigadeName'] as String?;
  return MyMissions(
    brigadeId: brigadeId,
    brigadeName: brigadeName,
    missions: [
      for (final mission in json['missions'] as List<Object?>? ?? const [])
        missionFromJson(
          mission! as Json,
          brigadeId: brigadeId ?? '',
          brigadeName: brigadeName ?? '',
        ),
    ],
  );
}

/// Maps one `Mission` of `/me/missions`.
Mission missionFromJson(
  Json json, {
  required String brigadeId,
  required String brigadeName,
}) {
  final people = json['people'] as Json? ?? const {};
  int count(String key) => (people[key] as num?)?.toInt() ?? 0;
  DateTime? time(String key) {
    final raw = json[key] as String?;
    return raw == null ? null : parseBackendTime(raw);
  }

  return Mission(
    id: json['planId']! as String,
    deliveryId: json['deliveryId'] as String?,
    category: MissionCategory.fromCode(json['category'] as String?),
    brigadeId: brigadeId,
    brigadeName: brigadeName,
    planId: json['planId']! as String,
    zoneId: json['zoneId']! as String,
    zoneName: json['zoneName']! as String,
    priority: PriorityLevel.fromCode(json['priorityLevel'] as String?),
    status: json['status'] == 'COMPLETED'
        ? MissionStatus.completed
        : MissionStatus.assigned,
    location: GeoPoint.fromJson(json['location']),
    score: (json['score'] as num?)?.toDouble(),
    people: ZonePeople(
      peopleAffected: count('peopleAffected'),
      children: count('children'),
      elderly: count('elderly'),
      disabled: count('disabled'),
    ),
    reasons: [
      for (final reason in json['reasons'] as List<Object?>? ?? const [])
        ScoreReason(
          ScoreFeature.fromCode((reason! as Json)['feature']! as String),
          ((reason as Json)['contribution'] as num? ?? 0).toDouble(),
        ),
    ]..sort((a, b) => b.points.compareTo(a.points)),
    items: [
      for (final item in json['items'] as List<Object?>? ?? const [])
        MissionItem(
          resourceId: (item! as Json)['resourceId']! as String,
          name: (item as Json)['name'] as String? ?? '',
          unit: item['unit'] as String?,
          quantity: (item['quantity'] as num? ?? 0).toInt(),
        ),
    ],
    assignedAt: time('assignedAt'),
    completedAt: time('completedAt'),
    baseDistanceKm: (json['distanceKm'] as num?)?.toDouble(),
    baseEtaMinutes: (json['etaMinutes'] as num?)?.toInt(),
  );
}
