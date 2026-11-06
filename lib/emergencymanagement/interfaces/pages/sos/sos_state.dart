part of 'sos_cubit.dart';

enum GpsStatus { locating, fixed, unavailable, denied }

class SosState extends Equatable {
  const SosState({
    this.category = HelpCategory.medical,
    this.gps = GpsStatus.locating,
    this.location,
    this.queued = 0,
    this.sending = false,
    this.failed = false,
    this.lastReport,
  });

  final HelpCategory category;
  final GpsStatus gps;
  final GeoPoint? location;
  final int queued;
  final bool sending;
  final bool failed;

  /// SOS just saved; the screen opens its optional detail (A_04).
  final CitizenReport? lastReport;

  SosState copyWith({
    HelpCategory? category,
    GpsStatus? gps,
    GeoPoint? location,
    int? queued,
    bool? sending,
    bool? failed,
    CitizenReport? lastReport,
  }) => SosState(
    category: category ?? this.category,
    gps: gps ?? this.gps,
    location: location ?? this.location,
    queued: queued ?? this.queued,
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
    lastReport: lastReport ?? this.lastReport,
  );

  @override
  List<Object?> get props => [
    category,
    gps,
    location,
    queued,
    sending,
    failed,
    lastReport,
  ];
}
