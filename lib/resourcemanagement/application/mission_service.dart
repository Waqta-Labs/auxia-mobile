import 'dart:async';

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

/// The account is not a member of any brigade yet: the administrator has
/// to add it (plan D3 and D4).
final class NoBrigadeLinked extends RefreshOutcome {
  const NoBrigadeLinked();
}

/// Use cases of Misiones y mapa (A_07).
class MissionService {
  MissionService(this._gateway, this._cache, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final MissionGateway _gateway;
  final MissionCache _cache;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController.broadcast();

  /// Fires when the device changes a mission: navigation started or delivery
  /// registered. A_07 stays alive in its tab while A_08 runs in another one.
  Stream<void> get changes => _changes.stream;

  /// What the brigadist saw last time, available without signal.
  Future<MissionsSnapshot> cached() async => MissionsSnapshot(
    missions: await _cache.missions(),
    brigadeName: await _cache.brigadeName(),
    lastRefresh: await _cache.lastRefresh(),
  );

  /// Asks the backend for the missions of the brigade of the session.
  Future<Either<Failure, RefreshOutcome>> refresh() async {
    final result = await _gateway.myMissions();
    if (result case Left(:final value)) return Left(value);
    final mine = result.getRight().toNullable()!;

    final known = await _cache.missions();
    await _cache.saveBrigadeName(mine.brigadeName);
    await _cache.replaceMissions([
      for (final fresh in mine.missions) _keepProgress(fresh, known),
    ]);
    await _cache.markRefreshed(_clock());
    if (!mine.hasBrigade) return const Right(NoBrigadeLinked());
    return Right(MissionsRefreshed(await cached()));
  }

  /// "Iniciar navegación": the mission becomes the active one.
  Future<void> startNavigation(Mission mission) async {
    await _cache.saveMission(mission.withStatus(MissionStatus.navigating));
    _changes.add(null);
  }

  /// The delivery [deliveryId] was registered (A_08).
  Future<void> complete(String deliveryId) async {
    for (final mission in await _cache.missions()) {
      if (mission.deliveryId == deliveryId) {
        await _cache.saveMission(mission.withStatus(MissionStatus.completed));
      }
    }
    _changes.add(null);
  }

  /// The backend does not know that the brigadist started navigating or
  /// already delivered offline; the device keeps that progress.
  static Mission _keepProgress(Mission fresh, List<Mission> known) {
    for (final mission in known) {
      if (mission.id == fresh.id && mission.status.index > fresh.status.index) {
        return fresh.withStatus(mission.status);
      }
    }
    return fresh;
  }
}
