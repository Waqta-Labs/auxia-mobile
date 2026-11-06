import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/maps/map_region.dart';
import '../../../application/offline_maps_service.dart';
import '../../../application/storage_stats.dart';

/// Message to show after a map action.
enum MapsNotice { noSpace, failed }

class NetworkStorageState extends Equatable {
  const NetworkStorageState({
    this.regions = const [],
    this.usedBytes = 0,
    this.budgetBytes = 0,
    this.stats = const StorageStats(),
    this.loading = true,
    this.notice,
  });

  final List<RegionState> regions;
  final int usedBytes;
  final int budgetBytes;
  final StorageStats stats;
  final bool loading;
  final MapsNotice? notice;

  NetworkStorageState copyWith({
    List<RegionState>? regions,
    int? usedBytes,
    int? budgetBytes,
    StorageStats? stats,
    bool? loading,
    MapsNotice? Function()? notice,
  }) => NetworkStorageState(
    regions: regions ?? this.regions,
    usedBytes: usedBytes ?? this.usedBytes,
    budgetBytes: budgetBytes ?? this.budgetBytes,
    stats: stats ?? this.stats,
    loading: loading ?? this.loading,
    notice: notice != null ? notice() : this.notice,
  );

  @override
  List<Object?> get props => [
    regions,
    usedBytes,
    budgetBytes,
    stats,
    loading,
    notice,
  ];
}

/// Red y almacenamiento (A_06 / A_09): offline maps and local database.
class NetworkStorageCubit extends Cubit<NetworkStorageState> {
  NetworkStorageCubit(
    this._maps,
    this._stats, {
    required this.loadRegions,
    required this._dataChanges,
  }) : super(const NetworkStorageState());

  final OfflineMapsService _maps;
  final StorageStatsSource _stats;

  /// Regions of the role: the zones of the missions and the own location.
  final Future<List<MapRegion>> Function() loadRegions;
  final Stream<void> _dataChanges;

  List<MapRegion> _regions = const [];
  final List<StreamSubscription<void>> _subscriptions = [];

  Future<void> start() async {
    _subscriptions
      ..add(_maps.changes.listen((_) => _emitRegions()))
      ..add(_dataChanges.listen((_) => unawaited(refreshStats())));
    _regions = await loadRegions();
    if (isClosed) return;
    _emitRegions(loading: false);
    await refreshStats();
  }

  Future<void> refreshStats() async {
    try {
      final stats = await _stats.read();
      if (!isClosed) emit(state.copyWith(stats: stats));
    } on Object {
      // A failed reading keeps the previous figures on screen.
    }
  }

  Future<void> download(MapRegion region) async {
    emit(state.copyWith(notice: () => null));
    final outcome = await _maps.download(region);
    if (isClosed) return;
    switch (outcome) {
      case DownloadOutcome.noSpace:
        emit(state.copyWith(notice: () => MapsNotice.noSpace));
      case DownloadOutcome.failed:
        emit(state.copyWith(notice: () => MapsNotice.failed));
      case DownloadOutcome.completed || DownloadOutcome.paused:
        _emitRegions();
    }
  }

  void pause(MapRegion region) => _maps.pause(region);

  Future<void> delete(MapRegion region) => _maps.delete(region, _regions);

  void _emitRegions({bool? loading}) {
    if (isClosed) return;
    emit(
      state.copyWith(
        regions: [for (final region in _regions) _maps.stateOf(region)],
        usedBytes: _maps.usedBytes(),
        budgetBytes: _maps.budgetBytes,
        loading: loading,
      ),
    );
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
