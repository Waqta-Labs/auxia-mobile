import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/mission.dart';

/// Port to the backend data a brigadist needs to know their missions.
abstract interface class MissionGateway {
  /// Brigades of the organization of the session.
  Future<Either<Failure, List<BrigadeSummary>>> brigades();

  /// Brigade with its current assignment.
  Future<Either<Failure, BrigadeSummary>> brigade(String brigadeId);

  /// Mission of the plan assigned to [brigade]: the plan, its zone with the
  /// explained score and the delivery opened for the brigade. Null if the
  /// plan has no delivery open for the brigade.
  Future<Either<Failure, Mission?>> missionFor(BrigadeSummary brigade);
}

/// Port to the copy of the missions kept on the device for offline work.
abstract interface class MissionCache {
  Future<String?> myBrigadeId();

  Future<void> saveMyBrigadeId(String? brigadeId);

  /// Missions seen by the brigadist, newest first.
  Future<List<Mission>> missions();

  Future<void> saveMission(Mission mission);

  Future<DateTime?> lastRefresh();

  Future<void> markRefreshed(DateTime when);
}
