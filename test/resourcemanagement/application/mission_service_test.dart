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
  final now = DateTime(2026, 11, 6, 9, 41);

  setUp(() async {
    db = await openTestDatabase();
    cache = SqliteMissionCache(db);
    gateway = FakeMissionGateway(mission: sampleMission());
  });

  tearDown(() => db.close());

  MissionService service() => MissionService(gateway, cache, clock: () => now);

  test('finds the brigade by the name of the brigadist', () async {
    final result = await service().refresh('cap. m. quispe');

    final outcome = result.getRight().toNullable()! as MissionsRefreshed;
    expect(outcome.snapshot.brigadeName, 'Brigada Alfa');
    expect(outcome.snapshot.missions.single.zoneName, 'Sector Santa Rosa');
    expect(outcome.snapshot.lastRefresh, now);
    expect(await cache.myBrigadeId(), 'brigade-alfa');
  });

  test('asks to choose when the name is in no brigade', () async {
    final result = await service().refresh('Luis Salazar');

    expect(result.getRight().toNullable(), isA<BrigadeChoiceNeeded>());
    expect(await cache.myBrigadeId(), isNull);
  });

  test('remembers the chosen brigade', () async {
    final missions = service();
    await missions.chooseBrigade('brigade-alfa');

    final result = await missions.refresh('Luis Salazar');

    expect(result.getRight().toNullable(), isA<MissionsRefreshed>());
  });

  test('keeps the cached missions when the backend fails', () async {
    await service().refresh('Cap. M. Quispe');
    gateway.failure = const NetworkFailure();

    final result = await service().refresh('Cap. M. Quispe');

    expect(result.isLeft(), isTrue);
    expect((await service().cached()).missions, hasLength(1));
  });

  test('a refresh does not undo the navigation started offline', () async {
    final missions = service();
    await missions.refresh('Cap. M. Quispe');
    await missions.startNavigation(sampleMission());

    await missions.refresh('Cap. M. Quispe');

    expect(
      (await missions.cached()).missions.single.status,
      MissionStatus.navigating,
    );
  });

  test('a completed delivery completes the mission', () async {
    final missions = service();
    await missions.refresh('Cap. M. Quispe');

    await missions.complete('delivery-1');

    expect(
      (await missions.cached()).missions.single.status,
      MissionStatus.completed,
    );
  });

  test('the cache keeps every field of the mission', () async {
    final mission = sampleMission();

    await cache.saveMission(mission);

    expect((await cache.missions()).single, mission);
  });
}
