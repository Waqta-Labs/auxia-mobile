part of 'emergency_detail_cubit.dart';

enum EvidenceIssue { microphone, camera }

class EmergencyDetailState extends Equatable {
  const EmergencyDetailState({
    this.detail = const EmergencyDetail(),
    this.recording = false,
    this.evidenceIssue,
    this.submitting = false,
    this.submitted = false,
    this.failed = false,
  });

  final EmergencyDetail detail;
  final bool recording;
  final EvidenceIssue? evidenceIssue;
  final bool submitting;
  final bool submitted;
  final bool failed;

  int count(PeopleGroup group) => switch (group) {
    PeopleGroup.children => detail.children,
    PeopleGroup.elderly => detail.elderly,
    PeopleGroup.injured => detail.injured,
  };

  EmergencyDetailState copyWith({
    EmergencyDetail? detail,
    bool? recording,
    EvidenceIssue? Function()? evidenceIssue,
    bool? submitting,
    bool? submitted,
    bool? failed,
  }) => EmergencyDetailState(
    detail: detail ?? this.detail,
    recording: recording ?? this.recording,
    evidenceIssue: evidenceIssue != null ? evidenceIssue() : this.evidenceIssue,
    submitting: submitting ?? this.submitting,
    submitted: submitted ?? this.submitted,
    failed: failed ?? this.failed,
  );

  @override
  List<Object?> get props => [
    detail,
    recording,
    evidenceIssue,
    submitting,
    submitted,
    failed,
  ];
}
