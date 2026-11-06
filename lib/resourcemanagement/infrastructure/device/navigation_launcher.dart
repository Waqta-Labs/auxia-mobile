import 'package:url_launcher/url_launcher.dart';

import '../../../shared/domain/geo_point.dart';

/// Opens turn-by-turn navigation to a mission in the maps app of the
/// device (Google Maps on Android, Apple Maps or Google Maps on iOS). Those
/// apps can also work with their own offline maps.
class NavigationLauncher {
  Future<bool> navigateTo(GeoPoint destination) async {
    final target = '${destination.latitude},${destination.longitude}';
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': target,
      'travelmode': 'driving',
    });
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
