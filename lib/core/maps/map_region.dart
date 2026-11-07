import 'package:equatable/equatable.dart';

import '../../shared/domain/geo_point.dart';

/// Area the user works in, listed on A_06 / A_09: the zone of a mission of
/// the brigade or the place where the user is.
///
/// The map of the app is drawn on the device from coordinates, without a map
/// tile server, so every region is available without signal.
final class MapRegion extends Equatable {
  const MapRegion({
    required this.id,
    required this.name,
    required this.center,
    this.assigned = false,
  });

  final String id;
  final String name;
  final GeoPoint center;

  /// Region of a mission of the brigade ("Sector Norte · Asignada").
  final bool assigned;

  @override
  List<Object> get props => [id, name, center, assigned];
}
