import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../core/maps/map_region.dart';
import '../../core/maps/offline_tile_store.dart';

/// Offline state of a region (A_06 / A_09).
final class RegionState extends Equatable {
  const RegionState({
    required this.region,
    required this.storedTiles,
    required this.totalTiles,
    required this.bytes,
    this.downloading = false,
  });

  final MapRegion region;
  final int storedTiles;
  final int totalTiles;

  /// Bytes on the device, or the estimate if nothing is stored yet.
  final int bytes;
  final bool downloading;

  bool get available => totalTiles > 0 && storedTiles >= totalTiles;

  bool get started => storedTiles > 0;

  int get percent =>
      totalTiles == 0 ? 0 : (storedTiles * 100 / totalTiles).floor();

  @override
  List<Object> get props => [
    region,
    storedTiles,
    totalTiles,
    bytes,
    downloading,
  ];
}

enum DownloadOutcome { completed, paused, noSpace, failed }

/// Downloads maps by region so navigation works without signal (report
/// 6.4.4: "descarga los mapas y la base de datos local").
class OfflineMapsService {
  OfflineMapsService(this._store, {this.budgetBytes = 200 * 1024 * 1024});

  final OfflineTileStore _store;

  /// Space the app allows itself for maps. Free disk space cannot be read
  /// without an extra plugin, so the app keeps its own limit.
  final int budgetBytes;

  final Map<String, RegionState> _running = {};
  final Set<String> _pauseRequested = {};
  final StreamController<void> _changes = StreamController.broadcast();

  Stream<void> get changes => _changes.stream;

  int usedBytes() => _store.totalBytes();

  RegionState stateOf(MapRegion region) {
    final running = _running[region.id];
    if (running != null) return running;
    final stored = _store.storedCount(region);
    return RegionState(
      region: region,
      storedTiles: stored,
      totalTiles: region.tiles().length,
      bytes: stored == 0
          ? _store.estimatedBytes(region)
          : _store.storedBytes(region),
    );
  }

  Future<DownloadOutcome> download(MapRegion region) async {
    if (_running.containsKey(region.id)) return DownloadOutcome.completed;
    final missing = region.tiles().length - _store.storedCount(region);
    if (usedBytes() + missing * _store.averageTileBytes > budgetBytes) {
      return DownloadOutcome.noSpace;
    }

    _pauseRequested.remove(region.id);
    _running[region.id] = stateOf(region);
    _notify();
    try {
      await _store.download(
        region,
        shouldStop: () => _pauseRequested.contains(region.id),
        onProgress: (done, total) {
          _running[region.id] = RegionState(
            region: region,
            storedTiles: done,
            totalTiles: total,
            bytes: _store.storedBytes(region),
            downloading: true,
          );
          _notify();
        },
      );
      return _pauseRequested.remove(region.id)
          ? DownloadOutcome.paused
          : DownloadOutcome.completed;
    } on Exception {
      return DownloadOutcome.failed;
    } finally {
      _running.remove(region.id);
      _notify();
    }
  }

  /// "Pausar": the tiles already saved stay; "Descargar" resumes.
  void pause(MapRegion region) => _pauseRequested.add(region.id);

  /// "Borrar", keeping the tiles that other regions still use.
  Future<void> delete(MapRegion region, List<MapRegion> others) async {
    await _store.delete(
      region,
      keep: [
        for (final other in others)
          if (other.id != region.id && _store.storedCount(other) > 0) other,
      ],
    );
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
