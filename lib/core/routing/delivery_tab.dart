import 'package:flutter/material.dart';

import '../../resourcemanagement/application/mission_service.dart';
import '../../resourcemanagement/domain/model/mission.dart';
import '../../traceability/domain/model/delivery.dart';

/// Anti-corruption layer between Resource Management and Traceability: the
/// delivery check receives its own [DeliveryOrder], never a [Mission]. Only
/// a mission whose delivery is open has one.
DeliveryOrder? deliveryOrderFrom(Mission mission) {
  final deliveryId = mission.deliveryId;
  if (deliveryId == null) return null;
  return DeliveryOrder(
    deliveryId: deliveryId,
    zoneName: mission.zoneName,
    brigadeName: mission.brigadeName,
    lines: [
      for (final item in mission.items)
        DeliveryLine(
          resourceId: item.resourceId,
          name: item.name.isEmpty ? item.resourceId.substring(0, 8) : item.name,
          unit: item.unit,
          planned: item.quantity,
          delivered: item.quantity,
        ),
    ],
  );
}

/// Delivery to check: the mission named in the route, else the one the
/// brigadist is navigating to.
Future<DeliveryOrder?> deliveryOrderFor(
  MissionService missions,
  String? missionId,
) async {
  final cached = (await missions.cached()).missions;
  Mission? chosen;
  for (final mission in cached) {
    if (missionId != null && mission.id == missionId) chosen = mission;
  }
  chosen ??= cached
      .where((mission) => mission.status == MissionStatus.navigating)
      .firstOrNull;
  return chosen == null ? null : deliveryOrderFrom(chosen);
}

/// Loads the order and hands it to the delivery screen.
class DeliveryTab extends StatelessWidget {
  const DeliveryTab({
    super.key,
    required this.missionId,
    required this.missions,
    required this.builder,
  });

  final String? missionId;
  final MissionService missions;
  final Widget Function(DeliveryOrder? order) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeliveryOrder?>(
      key: ValueKey(missionId),
      future: deliveryOrderFor(missions, missionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return builder(snapshot.data);
      },
    );
  }
}
