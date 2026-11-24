import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/maps/map_region.dart';
import '../../../application/service_status.dart';
import '../../../application/storage_stats.dart';

class NetworkStorageState extends Equatable {
  const NetworkStorageState({
    this.regions = const [],
    this.stats = const StorageStats(),
    this.loading = true,
    this.services = const ServiceStatus(),
  });

  final List<MapRegion> regions;
  final StorageStats stats;
  final bool loading;
  final ServiceStatus services;

  NetworkStorageState copyWith({
    List<MapRegion>? regions,
    StorageStats? stats,
    bool? loading,
    ServiceStatus? services,
  }) => NetworkStorageState(
    regions: regions ?? this.regions,
    stats: stats ?? this.stats,
    loading: loading ?? this.loading,
    services: services ?? this.services,
  );

  @override
  List<Object?> get props => [regions, stats, loading, services];
}

/// Red y almacenamiento (A_06 / A_09): regions of the map and local database.
class NetworkStorageCubit extends Cubit<NetworkStorageState> {
  NetworkStorageCubit(
    this._stats, {
    required this.loadRegions,
    required this._dataChanges,
    this._healthProbe,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const NetworkStorageState());

  final StorageStatsSource _stats;

  /// Regions of the role: the zones of the missions and the own location.
  final Future<List<MapRegion>> Function() loadRegions;
  final Stream<void> _dataChanges;
  final ServiceHealthProbe? _healthProbe;
  final DateTime Function() _clock;

  StreamSubscription<void>? _subscription;

  Future<void> start() async {
    _subscription = _dataChanges.listen((_) => unawaited(refreshStats()));
    final regions = await loadRegions();
    if (isClosed) return;
    emit(state.copyWith(regions: regions, loading: false));
    await refreshStats();
    // A cold start of the cloud can take long: the screen does not wait.
    unawaited(checkServices());
  }

  /// Asks every cloud service for its health, all at once.
  Future<void> checkServices() async {
    final probe = _healthProbe;
    if (probe == null || state.services.checking) return;
    emit(
      state.copyWith(
        services: ServiceStatus(
          health: {
            for (final service in CloudService.values)
              service: ServiceHealth.checking,
          },
          checkedAt: state.services.checkedAt,
        ),
      ),
    );
    final results = await Future.wait(
      CloudService.values.map(
        // Any error of the check means the service is not usable now.
        (service) => probe.isUp(service).catchError((Object _) => false),
      ),
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        services: ServiceStatus(
          health: {
            for (final (index, service) in CloudService.values.indexed)
              service: results[index] ? ServiceHealth.up : ServiceHealth.down,
          },
          checkedAt: _clock(),
        ),
      ),
    );
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
