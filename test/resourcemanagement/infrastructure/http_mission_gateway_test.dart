import 'package:auxia_mobile/resourcemanagement/domain/model/mission.dart';
import 'package:auxia_mobile/resourcemanagement/infrastructure/api/http_mission_gateway.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

const _brigade = BrigadeSummary(
  id: 'b1',
  name: 'Brigada Alfa',
  memberNames: ['Cap. M. Quispe'],
  distributionPlanId: 'p1',
);

Map<String, (int, Object?)> _routes({bool withScore = true}) => {
  'GET /api/v1/brigades': (
    200,
    [
      {
        'id': 'b1',
        'name': 'Brigada Alfa',
        'status': 'ASSIGNED',
        'members': [
          {'id': 'm1', 'fullName': 'Cap. M. Quispe', 'role': 'LEADER'},
        ],
        'currentAssignment': {'distributionPlanId': 'p1', 'brigadeId': 'b1'},
      },
      {'id': 'b2', 'name': 'Brigada Beta', 'members': <Object?>[]},
    ],
  ),
  'GET /api/v1/distribution-plans/p1': (
    200,
    {
      'id': 'p1',
      'zoneId': 'z1',
      'status': 'APPROVED',
      'items': [
        {'resourceId': 'r1', 'recommendedQuantity': 15, 'quantity': 12},
      ],
      'decision': {'decidedBy': 'u', 'decidedAt': '2026-11-06T10:00:00'},
    },
  ),
  'GET /api/v1/zones/z1': (
    200,
    {
      'id': 'z1',
      'name': 'Sector Santa Rosa',
      'geolocation': {'latitude': -12.0432, 'longitude': -77.0428},
      'damageLevel': 'SEVERE',
      'score': 93.6,
      'priorityLevel': 'CRITICAL',
      'populationImpact': {
        'peopleAffected': 120,
        'children': 3,
        'elderlyPeople': 1,
        'disabledPeople': 0,
      },
    },
  ),
  if (withScore)
    'GET /api/v1/zones/z1/score': (
      200,
      {
        'available': true,
        'score': 93.6,
        'priorityLevel': 'CRITICAL',
        'topFeatures': [
          {'feature': 'vulnerablePopulation', 'contribution': 12.5},
          {'feature': 'damageLevel', 'contribution': 30.0},
        ],
      },
    ),
  'GET /api/v1/deliveries': (
    200,
    [
      {
        'id': 'd-old',
        'distributionPlanId': 'p0',
        'brigadeId': 'b1',
        'status': 'CERTIFIED',
      },
      {
        'id': 'd1',
        'distributionPlanId': 'p1',
        'brigadeId': 'b1',
        'status': 'INITIATED',
      },
    ],
  ),
  'GET /api/v1/inventories': (
    200,
    {
      'id': 'i1',
      'stockItems': [
        {'resourceId': 'r1', 'name': 'Kit de víveres', 'unit': 'KIT'},
      ],
    },
  ),
};

void main() {
  test('lists the brigades with their members and assignment', () async {
    final gateway = HttpMissionGateway(
      fakeApiClient(FakeHttpAdapter(_routes())),
    );

    final brigades = (await gateway.brigades()).getRight().toNullable()!;

    expect(brigades.first, _brigade);
    expect(brigades.last.distributionPlanId, isNull);
  });

  test('builds the mission from plan, zone, score and delivery', () async {
    final adapter = FakeHttpAdapter(_routes());
    final gateway = HttpMissionGateway(fakeApiClient(adapter));

    final mission = (await gateway.missionFor(
      _brigade,
    )).getRight().toNullable()!;

    expect(mission.id, 'd1');
    expect(mission.zoneName, 'Sector Santa Rosa');
    expect(mission.location, const GeoPoint(-12.0432, -77.0428));
    expect(mission.score, 93.6);
    expect(mission.priority, PriorityLevel.critical);
    expect(mission.damage, DamageLevel.severe);
    expect(mission.status, MissionStatus.assigned);
    expect(mission.people.children, 3);
    expect(
      mission.reasons.first,
      const ScoreReason(ScoreFeature.damageLevel, 30),
    );
    expect(mission.items.single.name, 'Kit de víveres');
    expect(mission.items.single.quantity, 12);
    expect(mission.assignedAt, DateTime.utc(2026, 11, 6, 10));
    final deliveriesRequest = adapter.requests.firstWhere(
      (r) => r.uri.path == '/api/v1/deliveries',
    );
    expect(deliveriesRequest.uri.queryParameters, {'zoneId': 'z1'});
  });

  test('the mission works without the score explanation', () async {
    final gateway = HttpMissionGateway(
      fakeApiClient(FakeHttpAdapter(_routes(withScore: false))),
    );

    final mission = (await gateway.missionFor(
      _brigade,
    )).getRight().toNullable()!;

    expect(mission.reasons, isEmpty);
    expect(mission.score, 93.6);
  });

  test('a brigade without assignment has no mission', () async {
    final gateway = HttpMissionGateway(
      fakeApiClient(FakeHttpAdapter(_routes())),
    );

    final mission = await gateway.missionFor(
      const BrigadeSummary(id: 'b2', name: 'Beta', memberNames: []),
    );

    expect(mission.getRight().toNullable(), isNull);
  });

  test('names are matched without accents or case', () {
    const brigade = BrigadeSummary(
      id: 'b',
      name: 'B',
      memberNames: ['María  Quispe'],
    );

    expect(brigade.hasMember('maria quispe'), isTrue);
    expect(brigade.hasMember('Mario Quispe'), isFalse);
  });

  test('distance and time are estimated from the GPS', () {
    const here = GeoPoint(-12.0464, -77.0428);
    const there = GeoPoint(-12.0176, -77.0428);

    final km = here.distanceKmTo(there);

    expect(km, closeTo(3.2, 0.05));
    expect(estimatedMinutes(km), 12);
  });
}
