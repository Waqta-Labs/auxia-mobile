import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../domain/model/mission.dart';
import '../domain/repositories/mission_ports.dart';

/// Missions saved on the device.
final class MissionsSnapshot extends Equatable {
  const MissionsSnapshot({
    required this.missions,
    this.brigadeName,
    this.lastRefresh,
  });

  final List<Mission> missions;
  final String? brigadeName;
  final DateTime? lastRefresh;

  @override
  List<Object?> get props => [missions, brigadeName, lastRefresh];
}

/// Result of asking the backend for the missions.
sealed class RefreshOutcome {
  const RefreshOutcome();
}

final class MissionsRefreshed extends RefreshOutcome {
  const MissionsRefreshed(this.snapshot);

  final MissionsSnapshot snapshot;
}

/// The name of the brigadist is in none or in several brigades: they choose
/// theirs once and the device remembers it.
final class BrigadeChoiceNeeded extends RefreshOutcome {
  const BrigadeChoiceNeeded(this.brigades);

  final List<BrigadeSummary> brigades;
}

/// Use cases of Misiones y mapa (A_07).
class MissionService {
  MissionService(this._gateway, this._cache, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final MissionGateway _gateway;
  final MissionCache _cache;
  final DateTime Function() _clock;

  /// What the brigadist saw last time, available without signal.
  Future<MissionsSnapshot> cached() async {
    final missions = await _cache.missions();
    return MissionsSnapshot(
      missions: missions,
      brigadeName: missions.isEmpty ? null : missions.first.brigadeName,
      lastRefresh: await _cache.lastRefresh(),
    );
  }

  /// Asks the backend for the mission of the brigade of [fullName].
  Future<Either<Failure, RefreshOutcome>> refresh(String fullName) async {
    var brigadeId = await _cache.myBrigadeId();
    if (brigadeId == null) {
      final brigades = await _gateway.brigades();
      switch (brigades) {
        case Left(:final value):
          return Left(value);
        case Right(value: final all):
          final mine = all.where((b) => b.hasMember(fullName)).toList();
          if (mine.length != 1) return Right(BrigadeChoiceNeeded(all));
          brigadeId = mine.single.id;
          await _cache.saveMyBrigadeId(brigadeId);
      }
    }

    final brigade = await _gateway.brigade(brigadeId);
    if (brigade case Left(:final value)) {
      if (value is NotFoundFailure) await _cache.saveMyBrigadeId(null);
      return Left(value);
    }
    final summary = brigade.getRight().toNullable()!;

    final mission = await _gateway.missionFor(summary);
    if (mission case Left(:final value)) return Left(value);
    final fresh = mission.getRight().toNullable();
    if (fresh != null) await _cache.saveMission(await _keepProgress(fresh));

    await _cache.markRefreshed(_clock());
    final snapshot = await cached();
    return Right(
      MissionsRefreshed(
        MissionsSnapshot(
          missions: snapshot.missions,
          brigadeName: summary.name,
          lastRefresh: snapshot.lastRefresh,
        ),
      ),
    );
  }

  /// "Elige tu brigada".
  Future<void> chooseBrigade(String brigadeId) =>
      _cache.saveMyBrigadeId(brigadeId);

  /// "Iniciar navegación": the mission becomes the active one.
  Future<void> startNavigation(Mission mission) =>
      _cache.saveMission(mission.withStatus(MissionStatus.navigating));

  /// The delivery of the mission was registered (A_08).
  Future<void> complete(String missionId) async {
    for (final mission in await _cache.missions()) {
      if (mission.id == missionId) {
        await _cache.saveMission(mission.withStatus(MissionStatus.completed));
      }
    }
  }

  /// The backend does not know that the brigadist started navigating or
  /// already delivered offline; the device keeps that progress.
  Future<Mission> _keepProgress(Mission fresh) async {
    for (final known in await _cache.missions()) {
      if (known.id == fresh.id && known.status.index > fresh.status.index) {
        return fresh.withStatus(known.status);
      }
    }
    return fresh;
  }
}
