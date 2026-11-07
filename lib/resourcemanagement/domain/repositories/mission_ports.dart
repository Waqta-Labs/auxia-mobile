import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/mission.dart';

/// Missions of the brigade linked to the account of the session.
final class MyMissions extends Equatable {
  const MyMissions({required this.missions, this.brigadeId, this.brigadeName});

  /// Null while the account is not a member of any brigade.
  final String? brigadeId;
  final String? brigadeName;

  /// The assignment in progress first, then the completed ones, newest
  /// first.
  final List<Mission> missions;

  bool get hasBrigade => brigadeId != null;

  @override
  List<Object?> get props => [brigadeId, brigadeName, missions];
}

/// Port to the backend data a brigadist needs to know their missions.
abstract interface class MissionGateway {
  /// `GET /me/missions`: the missions of the brigade of the session.
  Future<Either<Failure, MyMissions>> myMissions();
}

/// Port to the copy of the missions kept on the device for offline work.
abstract interface class MissionCache {
  /// Name of the brigade of the account; null if it has none.
  Future<String?> brigadeName();

  Future<void> saveBrigadeName(String? name);

  /// Missions seen by the brigadist, in the order of the backend.
  Future<List<Mission>> missions();

  /// Replaces every mission with [missions], keeping their order.
  Future<void> replaceMissions(List<Mission> missions);

  Future<void> saveMission(Mission mission);

  Future<DateTime?> lastRefresh();

  Future<void> markRefreshed(DateTime when);
}
