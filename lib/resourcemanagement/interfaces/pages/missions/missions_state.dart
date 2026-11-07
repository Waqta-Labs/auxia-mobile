part of 'missions_cubit.dart';

class MissionsState extends Equatable {
  const MissionsState({
    this.snapshot = const MissionsSnapshot(missions: []),
    this.loading = true,
    this.refreshing = false,
    this.failure,
    this.noBrigade = false,
    this.myLocation,
  });

  final MissionsSnapshot snapshot;
  final bool loading;
  final bool refreshing;

  /// Why the last refresh failed; the cached missions are still shown.
  final Failure? failure;

  /// The account is not a member of any brigade yet.
  final bool noBrigade;
  final GeoPoint? myLocation;

  List<Mission> get missions => snapshot.missions;

  List<Mission> get openMissions =>
      missions.where((mission) => mission.isOpen).toList();

  /// The mission the brigadist is navigating to, or the first open one.
  Mission? get activeMission {
    for (final mission in missions) {
      if (mission.status == MissionStatus.navigating) return mission;
    }
    final open = openMissions;
    return open.isEmpty ? null : open.first;
  }

  MissionsState copyWith({
    MissionsSnapshot? snapshot,
    bool? loading,
    bool? refreshing,
    Failure? Function()? failure,
    bool? noBrigade,
    GeoPoint? myLocation,
  }) => MissionsState(
    snapshot: snapshot ?? this.snapshot,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
    failure: failure != null ? failure() : this.failure,
    noBrigade: noBrigade ?? this.noBrigade,
    myLocation: myLocation ?? this.myLocation,
  );

  @override
  List<Object?> get props => [
    snapshot,
    loading,
    refreshing,
    failure,
    noBrigade,
    myLocation,
  ];
}
