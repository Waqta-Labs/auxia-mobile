import 'package:equatable/equatable.dart';

/// GPS coordinates in decimal degrees (WGS 84), as the backend uses them.
final class GeoPoint extends Equatable {
  const GeoPoint(this.latitude, this.longitude)
    : assert(latitude >= -90 && latitude <= 90, 'latitude out of range'),
      assert(longitude >= -180 && longitude <= 180, 'longitude out of range');

  final double latitude;
  final double longitude;

  /// "-12.0464, -77.0428", the format of the mockups (A_03, A_07).
  String format({int decimals = 4}) =>
      '${latitude.toStringAsFixed(decimals)}, '
      '${longitude.toStringAsFixed(decimals)}';

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  static GeoPoint? fromJson(Object? json) {
    if (json is! Map) return null;
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (latitude is! num || longitude is! num) return null;
    return GeoPoint(latitude.toDouble(), longitude.toDouble());
  }

  @override
  List<Object> get props => [latitude, longitude];
}
