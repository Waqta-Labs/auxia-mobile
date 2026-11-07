import 'package:equatable/equatable.dart';

import '../../../shared/domain/geo_point.dart';

/// Kind of help asked with the SOS (report 6.2.2: Médico, Rescate, Víveres).
enum HelpCategory {
  medical('MEDICAL', 'Médico'),
  rescue('RESCUE', 'Rescate'),
  supplies('SUPPLIES', 'Víveres');

  const HelpCategory(this.code, this.spanishLabel);

  /// Code sent to the backend.
  final String code;

  /// Word used in the report text, always in Spanish for the NLP model.
  final String spanishLabel;

  static HelpCategory fromCode(String code) =>
      HelpCategory.values.firstWhere((category) => category.code == code);
}

/// Access conditions of the emergency detail (A_04, "Estado de acceso").
enum AccessCondition {
  roadBlocked('ROAD_BLOCKED', 'vía bloqueada'),
  noDrinkingWater('NO_DRINKING_WATER', 'sin agua potable'),
  noCellSignal('NO_CELL_SIGNAL', 'sin señal celular'),
  damagedBuilding('DAMAGED_BUILDING', 'edificio dañado');

  const AccessCondition(this.code, this.spanishText);

  final String code;
  final String spanishText;

  static AccessCondition fromCode(String code) =>
      AccessCondition.values.firstWhere((condition) => condition.code == code);
}

/// Optional detail added on A_04 when there is time.
final class EmergencyDetail extends Equatable {
  const EmergencyDetail({
    this.children = 0,
    this.elderly = 0,
    this.injured = 0,
    this.accessConditions = const {},
    this.audioPath,
    this.photoPath,
  }) : assert(children >= 0 && elderly >= 0 && injured >= 0, 'negative');

  static const int maxPeople = 99;

  final int children;
  final int elderly;
  final int injured;
  final Set<AccessCondition> accessConditions;

  /// Local files of the quick evidence (5 s audio and photo).
  final String? audioPath;
  final String? photoPath;

  bool get isEmpty =>
      children == 0 &&
      elderly == 0 &&
      injured == 0 &&
      accessConditions.isEmpty &&
      audioPath == null &&
      photoPath == null;

  EmergencyDetail copyWith({
    int? children,
    int? elderly,
    int? injured,
    Set<AccessCondition>? accessConditions,
    String? Function()? audioPath,
    String? Function()? photoPath,
  }) => EmergencyDetail(
    children: children ?? this.children,
    elderly: elderly ?? this.elderly,
    injured: injured ?? this.injured,
    accessConditions: accessConditions ?? this.accessConditions,
    audioPath: audioPath != null ? audioPath() : this.audioPath,
    photoPath: photoPath != null ? photoPath() : this.photoPath,
  );

  @override
  List<Object?> get props => [
    children,
    elderly,
    injured,
    accessConditions,
    audioPath,
    photoPath,
  ];
}

/// Steps a citizen report goes through (report 6.2.5, navigation by state).
enum CitizenReportStatus {
  /// Saved on the device ("Guardado en dispositivo").
  saved,

  /// Being sent ("Transmitiendo…").
  transmitting,

  /// Accepted by the backend, waiting for the AI prioritization.
  received,

  /// Prioritized by the AI ("Priorizado por IA"). The score is not public.
  prioritized,

  /// A brigade is on the way ("Brigada en camino", with the ETA if known).
  brigadeOnTheWay;

  static CitizenReportStatus fromName(String name) =>
      CitizenReportStatus.values.firstWhere((status) => status.name == name);

  /// How many of the four progress segments of A_05 are filled.
  int get completedSteps => switch (this) {
    saved => 1,
    transmitting || received => 2,
    prioritized => 3,
    brigadeOnTheWay => 4,
  };
}

/// SOS report of a citizen (A_03 to A_05).
final class CitizenReport extends Equatable {
  const CitizenReport({
    required this.id,
    required this.code,
    required this.category,
    required this.reportedAt,
    required this.status,
    this.location,
    this.detail = const EmergencyDetail(),
    this.etaMinutes,
  });

  /// Id generated on the device; the backend uses it to avoid duplicates.
  final String id;

  /// Short code shown to the citizen, such as SR-0412.
  final String code;
  final HelpCategory category;
  final DateTime reportedAt;
  final CitizenReportStatus status;
  final GeoPoint? location;
  final EmergencyDetail detail;

  /// Minutes until the brigade arrives, once assigned.
  final int? etaMinutes;

  /// Whether it is still on the device, so the detail can be added to it.
  bool get isUnsent => status == CitizenReportStatus.saved;

  CitizenReport withDetail(EmergencyDetail detail) => _copy(detail: detail);

  CitizenReport withLocation(GeoPoint location) => _copy(location: location);

  CitizenReport withStatus(CitizenReportStatus status, {int? etaMinutes}) =>
      _copy(status: status, etaMinutes: etaMinutes);

  CitizenReport _copy({
    EmergencyDetail? detail,
    GeoPoint? location,
    CitizenReportStatus? status,
    int? etaMinutes,
  }) => CitizenReport(
    id: id,
    code: code,
    category: category,
    reportedAt: reportedAt,
    status: status ?? this.status,
    location: location ?? this.location,
    detail: detail ?? this.detail,
    etaMinutes: etaMinutes ?? this.etaMinutes,
  );

  /// Free text for the backend, which structures field reports with its NLP
  /// model (US-01, US-02). It is always written in Spanish, the operational
  /// language of the report, whatever the language of the interface.
  String toReportText() => describe(category, detail, location);

  /// Text of a detail added after the SOS already left the device.
  String toFollowUpText() =>
      'Detalle adicional del reporte $code. '
      '${describe(category, detail, location)}';

  static String describe(
    HelpCategory category,
    EmergencyDetail detail,
    GeoPoint? location,
  ) {
    final parts = <String>['SOS ${category.spanishLabel}.'];
    final people = [
      if (detail.children > 0) _count(detail.children, 'niño', 'niños'),
      if (detail.elderly > 0)
        _count(detail.elderly, 'adulto mayor', 'adultos mayores'),
      if (detail.injured > 0) _count(detail.injured, 'herido', 'heridos'),
    ];
    if (people.isNotEmpty) {
      parts.add('Necesitan ayuda ${_join(people)}.');
    }
    if (detail.accessConditions.isNotEmpty) {
      final conditions = [
        for (final condition in AccessCondition.values)
          if (detail.accessConditions.contains(condition))
            condition.spanishText,
      ];
      final sentence = _join(conditions);
      parts.add('${sentence[0].toUpperCase()}${sentence.substring(1)}.');
    }
    if (location != null) {
      parts.add('Ubicación GPS ${location.format()}.');
    }
    return parts.join(' ');
  }

  static String _count(int value, String singular, String plural) =>
      '$value ${value == 1 ? singular : plural}';

  static String _join(List<String> items) => items.length == 1
      ? items.single
      : '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';

  @override
  List<Object?> get props => [
    id,
    code,
    category,
    reportedAt,
    status,
    location,
    detail,
    etaMinutes,
  ];
}
