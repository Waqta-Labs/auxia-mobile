import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/failure.dart';
import '../../../../core/location/location_service.dart';
import '../../../../shared/domain/geo_point.dart';
import '../../../application/mission_service.dart';
import '../../../domain/model/mission.dart';

part 'missions_state.dart';

/// Misiones y mapa (A_07): cached missions first, then the backend.
class MissionsCubit extends Cubit<MissionsState> {
  MissionsCubit(this._service, this._location, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const MissionsState());

  final MissionService _service;
  final LocationService _location;
  final DateTime Function() _clock;

  StreamSubscription<void>? _changes;

  Future<void> start() async {
    _changes = _service.changes.listen((_) => unawaited(_reload()));
    final cached = await _service.cached();
    if (isClosed) return;
    emit(state.copyWith(snapshot: cached, loading: false));
    await Future.wait([_locate(), refresh()]);
  }

  Future<void> refresh() async {
    emit(state.copyWith(refreshing: true, failure: () => null));
    final result = await _service.refresh();
    if (isClosed) return;
    result.fold(
      (failure) =>
          emit(state.copyWith(refreshing: false, failure: () => failure)),
      (outcome) => switch (outcome) {
        MissionsRefreshed(:final snapshot) => emit(
          state.copyWith(
            refreshing: false,
            snapshot: snapshot,
            noBrigade: false,
          ),
        ),
        NoBrigadeLinked() => emit(
          state.copyWith(
            refreshing: false,
            snapshot: const MissionsSnapshot(missions: []),
            noBrigade: true,
          ),
        ),
      },
    );
  }

  Future<void> startNavigation(Mission mission) async {
    await _service.startNavigation(mission);
    await _reload();
  }

  /// Shows what the device saved, such as a delivery registered on A_08.
  Future<void> _reload() async {
    final snapshot = await _service.cached();
    if (!isClosed) emit(state.copyWith(snapshot: snapshot));
  }

  Future<void> _locate() async {
    final result = await _location.locate();
    if (isClosed) return;
    if (result case LocationFix(:final point)) {
      emit(state.copyWith(myLocation: point));
    }
  }

  DateTime now() => _clock();

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
