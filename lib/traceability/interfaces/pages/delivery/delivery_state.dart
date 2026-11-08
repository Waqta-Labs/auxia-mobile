part of 'delivery_cubit.dart';

/// The three steps of A_08.
enum DeliveryStep { scan, evidence, blockchain }

class DeliveryState extends Equatable {
  const DeliveryState({
    required this.order,
    this.step = DeliveryStep.scan,
    this.wrongCode = false,
    this.signaturePath,
    this.photoPath,
    this.submitting = false,
    this.cameraFailed = false,
    this.record,
    this.location,
    this.locating = false,
  });

  final DeliveryOrder order;
  final DeliveryStep step;
  final bool wrongCode;
  final String? signaturePath;
  final String? photoPath;
  final bool submitting;
  final bool cameraFailed;

  /// The saved delivery, once registered from the device.
  final DeliveryRecord? record;

  /// Where the delivery happens (US-15), once the GPS answers.
  final GeoPoint? location;

  /// The GPS is being asked.
  final bool locating;

  bool get evidenceComplete =>
      signaturePath != null &&
      photoPath != null &&
      order.lines.any((line) => line.delivered > 0);

  /// Steps of the progress bar that are done.
  int get completedSteps => switch (step) {
    DeliveryStep.scan => 0,
    DeliveryStep.evidence => evidenceComplete ? 2 : 1,
    DeliveryStep.blockchain =>
      record?.status == DeliveryRecordStatus.anchored ? 3 : 2,
  };

  DeliveryState copyWith({
    DeliveryOrder? order,
    DeliveryStep? step,
    bool? wrongCode,
    String? Function()? signaturePath,
    String? Function()? photoPath,
    bool? submitting,
    bool? cameraFailed,
    DeliveryRecord? Function()? record,
    GeoPoint? Function()? location,
    bool? locating,
  }) => DeliveryState(
    order: order ?? this.order,
    step: step ?? this.step,
    wrongCode: wrongCode ?? this.wrongCode,
    signaturePath: signaturePath != null ? signaturePath() : this.signaturePath,
    photoPath: photoPath != null ? photoPath() : this.photoPath,
    submitting: submitting ?? this.submitting,
    cameraFailed: cameraFailed ?? this.cameraFailed,
    record: record != null ? record() : this.record,
    location: location != null ? location() : this.location,
    locating: locating ?? this.locating,
  );

  @override
  List<Object?> get props => [
    order,
    step,
    wrongCode,
    signaturePath,
    photoPath,
    submitting,
    cameraFailed,
    record,
    location,
    locating,
  ];
}
