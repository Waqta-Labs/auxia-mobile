import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/domain/geo_point.dart';
import '../../domain/model/mission.dart';
import '../../domain/repositories/mission_ports.dart';

typedef Json = Map<String, Object?>;

/// [MissionGateway] over the AuxIA backend (Backend/ENDPOINTS.md, section 4).
///
/// Brigade members are not linked to user accounts, so the mission is
/// reached through brigade → current assignment → distribution plan → zone →
/// delivery opened for the brigade.
class HttpMissionGateway implements MissionGateway {
  HttpMissionGateway(this._client);

  final ApiClient _client;

  @override
  Future<Either<Failure, List<BrigadeSummary>>> brigades() => _client.get(
    '/brigades',
    parse: (data) => [
      for (final brigade in data! as List<Object?>)
        brigadeFromJson(brigade! as Json),
    ],
  );

  @override
  Future<Either<Failure, BrigadeSummary>> brigade(String brigadeId) =>
      _client.get(
        '/brigades/$brigadeId',
        parse: (data) => brigadeFromJson(data! as Json),
      );

  @override
  Future<Either<Failure, Mission?>> missionFor(BrigadeSummary brigade) async {
    final planId = brigade.distributionPlanId;
    if (planId == null) return const Right(null);

    final plan = await _json('/distribution-plans/$planId');
    if (plan case Left(:final value)) return Left(value);
    final planJson = plan.getRight().toNullable()!;
    final zoneId = planJson['zoneId']! as String;

    final zone = await _json('/zones/$zoneId');
    if (zone case Left(:final value)) return Left(value);

    final deliveries = await _client.get(
      '/deliveries',
      query: {'zoneId': zoneId},
      parse: (data) => [for (final d in data! as List<Object?>) d! as Json],
    );
    if (deliveries case Left(:final value)) return Left(value);

    final delivery = _deliveryOf(
      deliveries.getRight().toNullable()!,
      brigadeId: brigade.id,
      planId: planId,
    );
    if (delivery == null) return const Right(null);

    // The explanation and the resource names enrich the card; the mission
    // is still usable without them.
    final score = (await _json('/zones/$zoneId/score')).toNullable();
    final names = (await _resourceNames()).getOrElse((_) => const {});

    return Right(
      missionFromJson(
        brigade: brigade,
        plan: planJson,
        zone: zone.getRight().toNullable()!,
        delivery: delivery,
        score: score,
        resourceNames: names,
      ),
    );
  }

  Future<Either<Failure, Json>> _json(String path) =>
      _client.get(path, parse: (data) => data! as Json);

  Future<Either<Failure, Map<String, (String, String?)>>> _resourceNames() =>
      _client.get(
        '/inventories',
        parse: (data) => {
          for (final item
              in ((data! as Json)['stockItems'] as List<Object?>? ?? const []))
            (item! as Json)['resourceId']! as String: (
              (item as Json)['name'] as String? ?? '',
              item['unit'] as String?,
            ),
        },
      );

  static Json? _deliveryOf(
    List<Json> deliveries, {
    required String brigadeId,
    required String planId,
  }) {
    final ofPlan = deliveries.where(
      (d) => d['distributionPlanId'] == planId && d['brigadeId'] == brigadeId,
    );
    for (final delivery in ofPlan) {
      if (delivery['status'] == 'INITIATED') return delivery;
    }
    return ofPlan.isEmpty ? null : ofPlan.first;
  }
}

/// Reads a backend `LocalDateTime` (UTC without zone) or an ISO date-time.
DateTime parseBackendTime(String raw) =>
    DateTime.parse(raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z');

BrigadeSummary brigadeFromJson(Json json) => BrigadeSummary(
  id: json['id']! as String,
  name: json['name']! as String,
  memberNames: [
    for (final member in json['members'] as List<Object?>? ?? const [])
      (member! as Json)['fullName']! as String,
  ],
  distributionPlanId:
      (json['currentAssignment'] as Json?)?['distributionPlanId'] as String?,
);

Mission missionFromJson({
  required BrigadeSummary brigade,
  required Json plan,
  required Json zone,
  required Json delivery,
  Json? score,
  Map<String, (String, String?)> resourceNames = const {},
}) {
  final impact = zone['populationImpact'] as Json? ?? const {};
  int count(String key) => (impact[key] as num?)?.toInt() ?? 0;
  final available = score?['available'] != false;
  final reasons = [
    if (available)
      for (final feature in score?['topFeatures'] as List<Object?>? ?? const [])
        ScoreReason(
          ScoreFeature.fromCode((feature! as Json)['feature']! as String),
          ((feature as Json)['contribution'] as num? ?? 0).toDouble(),
        ),
  ]..sort((a, b) => b.points.compareTo(a.points));
  final decidedAt = (plan['decision'] as Json?)?['decidedAt'] as String?;
  final deliveryStatus = delivery['status'] as String?;

  return Mission(
    id: delivery['id']! as String,
    brigadeId: brigade.id,
    brigadeName: brigade.name,
    planId: plan['id']! as String,
    zoneId: zone['id']! as String,
    zoneName: zone['name']! as String,
    priority: PriorityLevel.fromCode(
      (score?['priorityLevel'] ?? zone['priorityLevel']) as String?,
    ),
    status: deliveryStatus == 'INITIATED'
        ? MissionStatus.assigned
        : MissionStatus.completed,
    location: GeoPoint.fromJson(zone['geolocation']),
    score: ((score?['score'] ?? zone['score']) as num?)?.toDouble(),
    damage: DamageLevel.fromCode(zone['damageLevel'] as String?),
    people: ZonePeople(
      peopleAffected: count('peopleAffected'),
      children: count('children'),
      elderly: count('elderlyPeople'),
      disabled: count('disabledPeople'),
    ),
    reasons: reasons,
    items: [
      for (final item in plan['items'] as List<Object?>? ?? const [])
        MissionItem(
          resourceId: (item! as Json)['resourceId']! as String,
          name: resourceNames[(item as Json)['resourceId']]?.$1 ?? '',
          unit: resourceNames[item['resourceId']]?.$2,
          quantity:
              ((item['quantity'] ?? item['recommendedQuantity']) as num? ?? 0)
                  .toInt(),
        ),
    ],
    assignedAt: decidedAt == null ? null : parseBackendTime(decidedAt),
  );
}
