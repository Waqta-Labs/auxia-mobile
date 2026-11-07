import 'package:equatable/equatable.dart';

import '../../../shared/domain/geo_point.dart';

/// Kind of help of a mission (A_07 label), from the resources of its plan:
/// a plan with medicines is "Médico", any other is "Víveres" (plan D4).
enum MissionCategory {
  medical('MEDICAL'),
  supplies('SUPPLIES');

  const MissionCategory(this.code);

  final String code;

  static MissionCategory fromCode(String? code) =>
      code == 'MEDICAL' ? medical : supplies;
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

/// An assignment of the brigade (A_07, plan D4): the one in progress first,
/// then the completed ones. Its id is the plan, stable while the delivery
/// that A_08 registers is opened.
final class Mission extends Equatable {
  const Mission({
    required this.id,
    this.deliveryId,
    this.category = MissionCategory.supplies,
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
    this.completedAt,
    this.baseDistanceKm,
    this.baseEtaMinutes,
  });

  final String id;

  /// Delivery to register in A_08; null until the backend opens it.
  final String? deliveryId;
  final MissionCategory category;
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
  final DateTime? completedAt;

  /// Distance and travel time from the base of the brigade, computed by the
  /// backend (plan D1). The card prefers the live GPS when there is one.
  final double? baseDistanceKm;
  final int? baseEtaMinutes;

  bool get isOpen => status != MissionStatus.completed;

  /// Whether A_08 can register its delivery.
  bool get canRegisterDelivery => isOpen && deliveryId != null;

  Mission withStatus(MissionStatus status) => Mission(
    id: id,
    deliveryId: deliveryId,
    category: category,
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
    completedAt: completedAt,
    baseDistanceKm: baseDistanceKm,
    baseEtaMinutes: baseEtaMinutes,
  );

  @override
  List<Object?> get props => [
    id,
    deliveryId,
    category,
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
    completedAt,
    baseDistanceKm,
    baseEtaMinutes,
  ];
}

/// Average field speed of plan D1, the same the backend uses.
const double fieldSpeedKmPerHour = 30;

/// Minutes to travel [distanceKm] in a straight line at
/// [fieldSpeedKmPerHour], rounded up to the minute (plan D1).
int estimatedMinutes(double distanceKm) =>
    (distanceKm / fieldSpeedKmPerHour * 60).ceil().clamp(1, 24 * 60);
