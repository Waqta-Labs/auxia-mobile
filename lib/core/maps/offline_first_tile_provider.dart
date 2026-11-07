import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_region.dart';
import 'offline_tile_store.dart';

/// Serves the tiles downloaded for offline use first and asks the network
/// only for the rest.
///
/// The [NetworkTileProvider] of flutter_map 8 only implements the cancelable
/// variant, so this provider uses it too: calling its `getImage` throws.
class OfflineFirstTileProvider extends TileProvider {
  OfflineFirstTileProvider(this._store, {NetworkTileProvider? network})
    : _network = network ?? NetworkTileProvider();

  final OfflineTileStore _store;
  final NetworkTileProvider _network;

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    final file = _store.fileOf(
      TileId(coordinates.z, coordinates.x, coordinates.y),
    );
    if (file.existsSync()) return FileImage(file);
    // The tile layer sets its headers (User-Agent) on this provider.
    _network.headers
      ..clear()
      ..addAll(headers);
    return _network.getImageWithCancelLoadingSupport(
      coordinates,
      options,
      cancelLoading,
    );
  }

  @override
  void dispose() {
    _network.dispose();
    super.dispose();
  }
}
