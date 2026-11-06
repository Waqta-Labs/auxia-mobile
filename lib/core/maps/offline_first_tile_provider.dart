import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_region.dart';
import 'offline_tile_store.dart';

/// Serves the tiles downloaded for offline use first and asks the network
/// only for the rest.
class OfflineFirstTileProvider extends TileProvider {
  OfflineFirstTileProvider(this._store);

  final OfflineTileStore _store;
  final NetworkTileProvider _network = NetworkTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final file = _store.fileOf(
      TileId(coordinates.z, coordinates.x, coordinates.y),
    );
    if (file.existsSync()) return FileImage(file);
    return _network.getImage(coordinates, options);
  }

  @override
  void dispose() {
    _network.dispose();
    super.dispose();
  }
}
