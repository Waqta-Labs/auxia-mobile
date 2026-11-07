import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/maps/map_region.dart';
import '../../../application/storage_stats.dart';

class NetworkStorageState extends Equatable {
  const NetworkStorageState({
    this.regions = const [],
    this.stats = const StorageStats(),
    this.loading = true,
  });

  final List<MapRegion> regions;
  final StorageStats stats;
  final bool loading;

  NetworkStorageState copyWith({
    List<MapRegion>? regions,
    StorageStats? stats,
    bool? loading,
  }) => NetworkStorageState(
    regions: regions ?? this.regions,
    stats: stats ?? this.stats,
    loading: loading ?? this.loading,
  );

  @override
  List<Object?> get props => [regions, stats, loading];
}

/// Red y almacenamiento (A_06 / A_09): regions of the map and local database.
class NetworkStorageCubit extends Cubit<NetworkStorageState> {
  NetworkStorageCubit(
    this._stats, {
    required this.loadRegions,
    required this._dataChanges,
  }) : super(const NetworkStorageState());

  final StorageStatsSource _stats;

  /// Regions of the role: the zones of the missions and the own location.
  final Future<List<MapRegion>> Function() loadRegions;
  final Stream<void> _dataChanges;

  StreamSubscription<void>? _subscription;

  Future<void> start() async {
    _subscription = _dataChanges.listen((_) => unawaited(refreshStats()));
    final regions = await loadRegions();
    if (isClosed) return;
    emit(state.copyWith(regions: regions, loading: false));
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

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
