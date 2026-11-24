import 'package:auxia_mobile/core/theme/app_colors.dart';
import 'package:auxia_mobile/resourcemanagement/domain/model/mission.dart';
import 'package:auxia_mobile/resourcemanagement/interfaces/widgets/missions_map.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  Widget map(List<Mission> missions, {GeoPoint? me}) => localizedApp(
    Scaffold(
      body: SizedBox(
        height: 280,
        child: MissionsMap(
          missions: missions,
          activeMission: missions.isEmpty ? null : missions.first,
          myLocation: me,
          overlayLabel: 'misiones',
        ),
      ),
    ),
  );

  testWidgets('frames the missions that arrive after the map opens', (
    tester,
  ) async {
    // Opens before the missions load, centered on Lima.
    await tester.pumpWidget(map(const []));
    await tester.pumpAndSettle();

    // The mission is in Chaclacayo, about 30 km away, with the brigadist.
    await tester.pumpWidget(
      map([
        sampleMission(location: const GeoPoint(-11.9436, -76.7078)),
      ], me: const GeoPoint(-11.9767, -76.77)),
    );
    await tester.pumpAndSettle();

    expect(find.text('94'), findsOneWidget);
  });

  test('a critical mission glows coral, the others in their color', () {
    expect(glowColor(94), AppColors.coral);
    expect(glowColor(78), scoreColor(78));
    expect(glowColor(null), scoreColor(null));
  });
}
