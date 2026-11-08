import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/resourcemanagement/application/mission_service.dart';
import 'package:auxia_mobile/resourcemanagement/domain/model/mission.dart';
import 'package:auxia_mobile/resourcemanagement/infrastructure/persistence/sqlite_mission_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late SqliteMissionCache cache;
  late FakeMissionGateway gateway;
  final now = DateTime(2026, 11, 7, 9, 41);

  setUp(() async {
    db = await openTestDatabase();
    cache = SqliteMissionCache(db);
    gateway = FakeMissionGateway(mission: sampleMission());
  });

  tearDown(() => db.close());

  MissionService service() => MissionService(gateway, cache, clock: () => now);

  test('reads the missions of the brigade of the account', () async {
    final result = await service().refresh();

    final outcome = result.getRight().toNullable()! as MissionsRefreshed;
    expect(outcome.snapshot.brigadeName, 'Brigada Alfa');
    expect(outcome.snapshot.missions.single.zoneName, 'Sector Santa Rosa');
    expect(outcome.snapshot.lastRefresh, now);
  });

  test('an account without brigade has no missions', () async {
    await service().refresh();
    gateway
      ..brigadeName = null
      ..mission = null;

    final result = await service().refresh();

    expect(result.getRight().toNullable(), isA<NoBrigadeLinked>());
    final cached = await service().cached();
    expect(cached.missions, isEmpty);
    expect(cached.brigadeName, isNull);
  });

  test('keeps the cached missions when the backend fails', () async {
    await service().refresh();
    gateway.failure = const NetworkFailure();

    final result = await service().refresh();

    expect(result.isLeft(), isTrue);
    expect((await service().cached()).missions, hasLength(1));
  });

  test('a refresh does not undo the navigation started offline', () async {
    final missions = service();
    await missions.refresh();
    await missions.startNavigation(sampleMission());

    await missions.refresh();

    expect(
      (await missions.cached()).missions.single.status,
      MissionStatus.navigating,
    );
  });

  test('the registered delivery completes its mission', () async {
    final missions = service();
    await missions.refresh();

    await missions.complete('delivery-1');

    expect(
      (await missions.cached()).missions.single.status,
      MissionStatus.completed,
    );
  });

  test('a refused delivery opens its mission again', () async {
    final missions = service();
    await missions.refresh();
    await missions.complete('delivery-1');

    await missions.reopen('delivery-1');
    // The backend still has it assigned: the refresh keeps it open.
    await missions.refresh();

    expect(
      (await missions.cached()).missions.single.status,
      MissionStatus.navigating,
    );
  });

  test('a mission completed in the backend is shown as completed', () async {
    final missions = service();
    await missions.refresh();
    await missions.startNavigation(sampleMission());
    gateway.mission = sampleMission(status: MissionStatus.completed);

    await missions.refresh();

    expect(
      (await missions.cached()).missions.single.status,
      MissionStatus.completed,
    );
  });

  test('the cache keeps the order and every field of the missions', () async {
    final current = sampleMission();
    final done = sampleMission(
      id: 'plan-0',
      deliveryId: 'delivery-0',
      status: MissionStatus.completed,
    );

    await cache.replaceMissions([current, done]);
    await cache.saveMission(current.withStatus(MissionStatus.navigating));

    final saved = await cache.missions();
    expect(saved.map((mission) => mission.id), ['plan-1', 'plan-0']);
    expect(saved.last, done);
    expect(saved.first, current.withStatus(MissionStatus.navigating));
  });

  test('the travel time uses 30 km/h rounded up', () {
    expect(estimatedMinutes(3.2), 7);
    expect(estimatedMinutes(0.4), 1);
  });
}
