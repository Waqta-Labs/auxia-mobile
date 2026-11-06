import 'package:equatable/equatable.dart';

import '../../../shared/domain/geo_point.dart';

/// Brigade of the organization, as the brigadist sees it.
final class BrigadeSummary extends Equatable {
  const BrigadeSummary({
    required this.id,
    required this.name,
    required this.memberNames,
    this.distributionPlanId,
  });

  final String id;
  final String name;
  final List<String> memberNames;

  /// Plan of the mission in progress, if the Command Center dispatched it.
  final String? distributionPlanId;

  /// Whether a person with this name belongs to the brigade. Accents, case
  /// and extra spaces are ignored.
  bool hasMember(String fullName) {
    final wanted = normalizeName(fullName);
    return memberNames.any((name) => normalizeName(name) == wanted);
  }

  static String normalizeName(String name) {
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    final lower = name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    return lower.split('').map((c) => accents[c] ?? c).join();
  }

  @override
  List<Object?> get props => [id, name, memberNames, distributionPlanId];
}

/// Priority computed by the AI for a zone.
enum PriorityLevel {
  low,
  medium,
  high,
  critical;

  static PriorityLevel fromCode(String? code) => switch (code) {
    'CRITICAL' => critical,
    'HIGH' => high,
    'MEDIUM' => medium,
    _ => low,
  };
}

/// Damage observed in a zone.
enum DamageLevel {
  low,
  moderate,
  severe,
  critical;

  static DamageLevel? fromCode(String? code) => switch (code) {
    'LOW' => low,
    'MODERATE' => moderate,
    'SEVERE' => severe,
    'CRITICAL' => critical,
    _ => null,
  };
}

/// Variables the AI weighs in the Urgency Score (AI Service).
enum ScoreFeature {
  damageLevel,
  peopleAffected,
  vulnerablePopulation,
  needs,
  other;

  static ScoreFeature fromCode(String code) => ScoreFeature.values.firstWhere(
    (feature) => feature.name == code,
    orElse: () => other,
  );
}

/// One reason of the priority: a variable and the points it added (US-05,
/// explainable AI).
final class ScoreReason extends Equatable {
  const ScoreReason(this.feature, this.points);

  final ScoreFeature feature;
  final double points;

  @override
  List<Object> get props => [feature, points];
}

/// People of the zone, from the population impact of the backend.
final class ZonePeople extends Equatable {
  const ZonePeople({
    this.peopleAffected = 0,
    this.children = 0,
    this.elderly = 0,
    this.disabled = 0,
  });

  final int peopleAffected;
  final int children;
  final int elderly;
  final int disabled;

  @override
  List<Object> get props => [peopleAffected, children, elderly, disabled];
}

/// A resource of the approved plan that the brigade must deliver.
final class MissionItem extends Equatable {
  const MissionItem({
    required this.resourceId,
    required this.name,
    required this.quantity,
    this.unit,
  });

  final String resourceId;
  final String name;
  final int quantity;

  /// UNIT, KG, LITER or KIT.
  final String? unit;

  @override
  List<Object?> get props => [resourceId, name, quantity, unit];
}

/// Where the mission is in the brigadist flow (report 6.2.5).
enum MissionStatus {
  /// Dispatched by the Command Center ("Misión asignada").
  assigned,

  /// The brigadist started the navigation ("Navegación hacia incidente").
  navigating,

  /// The delivery was registered ("Misión completada").
  completed,
}

/// A delivery the Command Center assigned to the brigade (A_07). Its id is
/// the id of the delivery in the backend, which A_08 registers.
final class Mission extends Equatable {
  const Mission({
    required this.id,
    required this.brigadeId,
    required this.brigadeName,
    required this.planId,
    required this.zoneId,
    required this.zoneName,
    required this.priority,
    required this.status,
    this.location,
    this.score,
    this.damage,
    this.people = const ZonePeople(),
    this.reasons = const [],
    this.items = const [],
    this.assignedAt,
  });

  final String id;
  final String brigadeId;
  final String brigadeName;
  final String planId;
  final String zoneId;
  final String zoneName;
  final PriorityLevel priority;
  final MissionStatus status;
  final GeoPoint? location;

  /// Urgency Score of the zone (0 to 100).
  final double? score;
  final DamageLevel? damage;
  final ZonePeople people;

  /// Largest contributions to the score, biggest first.
  final List<ScoreReason> reasons;
  final List<MissionItem> items;

  /// When the plan was approved.
  final DateTime? assignedAt;

  bool get isOpen => status != MissionStatus.completed;

  Mission withStatus(MissionStatus status) => Mission(
    id: id,
    brigadeId: brigadeId,
    brigadeName: brigadeName,
    planId: planId,
    zoneId: zoneId,
    zoneName: zoneName,
    priority: priority,
    status: status,
    location: location,
    score: score,
    damage: damage,
    people: people,
    reasons: reasons,
    items: items,
    assignedAt: assignedAt,
  );

  @override
  List<Object?> get props => [
    id,
    brigadeId,
    brigadeName,
    planId,
    zoneId,
    zoneName,
    priority,
    status,
    location,
    score,
    damage,
    people,
    reasons,
    items,
    assignedAt,
  ];
}

/// Road distance is unknown offline; the app estimates the travel time with
/// the average speed of the mockup example (3.2 km in 12 min).
const double fieldSpeedKmPerHour = 16;

/// Minutes to travel [distanceKm] at [fieldSpeedKmPerHour].
int estimatedMinutes(double distanceKm) =>
    (distanceKm / fieldSpeedKmPerHour * 60).round().clamp(1, 24 * 60);
