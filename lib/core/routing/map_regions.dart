import '../../resourcemanagement/application/mission_service.dart';
import '../location/location_service.dart';
import '../maps/map_region.dart';

/// Regions listed on A_06 / A_09: the zone of each open mission of the
/// brigadist ("· Asignada") and the place where the user is.
Future<List<MapRegion>> offlineRegions({
  required LocationService location,
  required String myLocationName,
  MissionService? missions,
}) async {
  final regions = <MapRegion>[];
  if (missions != null) {
    for (final mission in (await missions.cached()).missions) {
      final center = mission.location;
      if (center == null || !mission.isOpen) continue;
      regions.add(
        MapRegion(
          id: 'zone-${mission.zoneId}',
          name: mission.zoneName,
          center: center,
          assigned: true,
        ),
      );
    }
  }
  final here = await location.locate(timeout: const Duration(seconds: 5));
  if (here is LocationFix) {
    regions.add(
      MapRegion(id: 'my-location', name: myLocationName, center: here.point),
    );
  }
  return regions;
}
