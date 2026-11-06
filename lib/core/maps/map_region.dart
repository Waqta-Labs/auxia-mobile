import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../shared/domain/geo_point.dart';

/// Web Mercator tile (z/x/y), the scheme of the map tile providers.
final class TileId extends Equatable {
  const TileId(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  @override
  List<Object> get props => [z, x, y];
}

/// Rectangular area of the map that can be downloaded for offline use.
final class MapRegion extends Equatable {
  const MapRegion({
    required this.id,
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    this.assigned = false,
  });

  /// Square of about [radiusKm] around [center].
  factory MapRegion.around({
    required String id,
    required String name,
    required GeoPoint center,
    double radiusKm = 1.5,
    bool assigned = false,
  }) {
    final dLat = radiusKm / 111.32;
    final dLon =
        radiusKm / (111.32 * math.cos(center.latitude * math.pi / 180));
    return MapRegion(
      id: id,
      name: name,
      south: center.latitude - dLat,
      west: center.longitude - dLon,
      north: center.latitude + dLat,
      east: center.longitude + dLon,
      assigned: assigned,
    );
  }

  final String id;
  final String name;
  final double south;
  final double west;
  final double north;
  final double east;

  /// Region of a mission of the brigade ("Sector Norte · Asignada").
  final bool assigned;

  /// Zoom levels saved for offline use: from the district to the street.
  static const List<int> zooms = [12, 13, 14, 15, 16];

  /// Tiles that cover the region at [zooms].
  List<TileId> tiles() => [for (final z in zooms) ..._tilesAt(z)];

  Iterable<TileId> _tilesAt(int z) sync* {
    final minX = _x(west, z);
    final maxX = _x(east, z);
    final minY = _y(north, z);
    final maxY = _y(south, z);
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        yield TileId(z, x, y);
      }
    }
  }

  static int _x(double longitude, int z) =>
      ((longitude + 180) / 360 * (1 << z)).floor();

  static int _y(double latitude, int z) {
    final rad = latitude * math.pi / 180;
    final n = math.log(math.tan(rad) + 1 / math.cos(rad));
    return ((1 - n / math.pi) / 2 * (1 << z)).floor();
  }

  @override
  List<Object> get props => [id, name, south, west, north, east, assigned];
}
