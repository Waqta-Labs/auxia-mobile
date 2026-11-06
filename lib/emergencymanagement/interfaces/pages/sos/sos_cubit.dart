import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/location/location_service.dart';
import '../../../../shared/domain/geo_point.dart';
import '../../../application/sos_service.dart';
import '../../../domain/model/citizen_report.dart';

part 'sos_state.dart';

/// One-tap SOS (A_03): category, GPS status and the local queue.
class SosCubit extends Cubit<SosState> {
  SosCubit(this._service, this._location) : super(const SosState());

  final SosService _service;
  final LocationService _location;
  StreamSubscription<void>? _queueSubscription;

  /// Looks for the GPS and follows the queue. The SOS does not wait for it.
  Future<void> start() async {
    _queueSubscription = _service.queueChanges.listen(
      (_) => unawaited(_refreshQueue()),
    );
    await _refreshQueue();
    await locate();
  }

  Future<void> locate() async {
    emit(state.copyWith(gps: GpsStatus.locating));
    final result = await _location.locate();
    if (isClosed) return;
    switch (result) {
      case LocationFix(:final point):
        emit(state.copyWith(gps: GpsStatus.fixed, location: point));
        final pending = state.lastReport;
        if (pending != null && pending.location == null) {
          await _service.attachLocation(pending.id, point);
        }
      case LocationUnavailable(:final issue):
        emit(
          state.copyWith(
            gps: issue == LocationIssue.permissionDenied
                ? GpsStatus.denied
                : GpsStatus.unavailable,
          ),
        );
    }
  }

  void selectCategory(HelpCategory category) =>
      emit(state.copyWith(category: category));

  /// Saves and queues the SOS with the selected category.
  Future<void> sendSos() async {
    if (state.sending) return;
    emit(state.copyWith(sending: true, failed: false));
    final result = await _service.sendSos(
      category: state.category,
      location: state.location,
    );
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(sending: false, failed: true)),
      (report) => emit(state.copyWith(sending: false, lastReport: report)),
    );
  }

  Future<void> _refreshQueue() async {
    final queued = await _service.queuedReports();
    if (!isClosed) emit(state.copyWith(queued: queued));
  }

  @override
  Future<void> close() async {
    await _queueSubscription?.cancel();
    return super.close();
  }
}
