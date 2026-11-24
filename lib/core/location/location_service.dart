import 'package:geolocator/geolocator.dart';

import '../../shared/domain/geo_point.dart';

/// Why the device has no GPS fix.
enum LocationIssue { serviceDisabled, permissionDenied, unavailable }

/// Result of asking for the position: a point or the reason there is none.
sealed class LocationResult {
  const LocationResult();
}

final class LocationFix extends LocationResult {
  const LocationFix(this.point);

  final GeoPoint point;
}

final class LocationUnavailable extends LocationResult {
  const LocationUnavailable(this.issue);

  final LocationIssue issue;
}

/// Port to the GPS of the device. GPS works without network, so the SOS
/// report always tries to carry the position.
abstract interface class LocationService {
  /// Asks for permission if needed and returns the current position, or the
  /// last known one when a fresh fix takes longer than [timeout].
  Future<LocationResult> locate({Duration timeout});
}

/// [LocationService] over `geolocator`.
class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> locate({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(LocationIssue.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationUnavailable(LocationIssue.permissionDenied);
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(timeLimit: timeout),
        );
        return LocationFix(GeoPoint(position.latitude, position.longitude));
      } on Exception {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          return const LocationUnavailable(LocationIssue.unavailable);
        }
        return LocationFix(GeoPoint(last.latitude, last.longitude));
      }
    } on Exception {
      return const LocationUnavailable(LocationIssue.unavailable);
    }
  }
}
