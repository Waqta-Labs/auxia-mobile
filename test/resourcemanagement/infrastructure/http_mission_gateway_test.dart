import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/resourcemanagement/domain/model/mission.dart';
import 'package:auxia_mobile/resourcemanagement/infrastructure/api/http_mission_gateway.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// Example of the contract in PLAN_BACK_MOBILE.md, iteration 2.
const _missions = {
  'brigadeId': 'b1',
  'brigadeName': 'Brigada Alfa',
  'missions': [
    {
      'deliveryId': 'd1',
      'planId': 'p1',
      'zoneId': 'z1',
      'zoneName': 'Sector Santa Rosa',
      'status': 'ASSIGNED',
      'category': 'MEDICAL',
      'assignedAt': '2026-11-06T09:30:00',
      'completedAt': null,
      'score': 94.0,
      'priorityLevel': 'CRITICAL',
      'reasons': [
        {'feature': 'needs', 'contribution': 7.5},
        {'feature': 'damageLevel', 'contribution': 40.0},
      ],
      'people': {
        'peopleAffected': 300,
        'children': 3,
        'elderly': 1,
        'disabled': 0,
      },
      'location': {'latitude': -12.0432, 'longitude': -77.0428},
      'distanceKm': 3.2,
      'etaMinutes': 7,
      'items': [
        {
          'resourceId': 'r1',
          'name': 'Agua 2.5 L',
          'unit': 'UNIT',
          'quantity': 300,
        },
      ],
    },
    {
      'deliveryId': 'd0',
      'planId': 'p0',
      'zoneId': 'z0',
      'zoneName': 'Villa Esperanza',
      'status': 'COMPLETED',
      'category': 'SUPPLIES',
      'assignedAt': '2026-11-05T08:00:00',
      'completedAt': '2026-11-05T12:00:00',
    },
  ],
};

void main() {
  test('reads the missions of the brigade of the session', () async {
    final adapter = FakeHttpAdapter({
      'GET /api/v1/me/missions': (200, _missions),
    });

    final result = await HttpMissionGateway(
      fakeApiClient(adapter, token: 't'),
    ).myMissions();

    final mine = result.getRight().toNullable()!;
    expect(mine.brigadeName, 'Brigada Alfa');
    expect(mine.missions, hasLength(2));
    final current = mine.missions.first;
    expect(current.id, 'p1');
    expect(current.deliveryId, 'd1');
    expect(current.category, MissionCategory.medical);
    expect(current.status, MissionStatus.assigned);
    expect(current.priority, PriorityLevel.critical);
    expect(current.score, 94);
    expect(current.reasons.first.feature, ScoreFeature.damageLevel);
    expect(current.people.children, 3);
    expect(current.location, const GeoPoint(-12.0432, -77.0428));
    expect(current.baseDistanceKm, 3.2);
    expect(current.baseEtaMinutes, 7);
    expect(current.items.single.name, 'Agua 2.5 L');
    expect(current.assignedAt, DateTime.utc(2026, 11, 6, 9, 30));
    final done = mine.missions.last;
    expect(done.status, MissionStatus.completed);
    expect(done.category, MissionCategory.supplies);
    expect(done.completedAt, DateTime.utc(2026, 11, 5, 12));
  });

  test('an account without brigade gets no missions', () async {
    final adapter = FakeHttpAdapter({
      'GET /api/v1/me/missions': (
        200,
        {'brigadeId': null, 'brigadeName': null, 'missions': <Object?>[]},
      ),
    });

    final result = await HttpMissionGateway(
      fakeApiClient(adapter, token: 't'),
    ).myMissions();

    final mine = result.getRight().toNullable()!;
    expect(mine.hasBrigade, isFalse);
    expect(mine.missions, isEmpty);
  });

  test('a mission whose delivery is not open cannot be registered', () {
    final mission = missionFromJson(
      {
        'planId': 'p1',
        'zoneId': 'z1',
        'zoneName': 'Z',
        'status': 'ASSIGNED',
        'deliveryId': null,
      },
      brigadeId: 'b1',
      brigadeName: 'B',
    );

    expect(mission.canRegisterDelivery, isFalse);
  });

  test('another role is forbidden', () async {
    final adapter = FakeHttpAdapter({
      'GET /api/v1/me/missions': (403, {'detail': 'Forbidden'}),
    });

    final result = await HttpMissionGateway(
      fakeApiClient(adapter, token: 't'),
    ).myMissions();

    expect(result.getLeft().toNullable(), isA<ForbiddenFailure>());
  });
}
