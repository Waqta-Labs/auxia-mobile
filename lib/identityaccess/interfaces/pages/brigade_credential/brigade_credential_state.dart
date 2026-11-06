part of 'brigade_credential_cubit.dart';

class BrigadeCredentialState extends Equatable {
  const BrigadeCredentialState({
    this.organization = '',
    this.brigadeCode = '',
    this.idCardPhotoPath,
    this.organizationError,
    this.brigadeCodeError,
    this.submitting = false,
    this.submitted = false,
    this.failed = false,
    this.cameraFailed = false,
  });

  final String organization;
  final String brigadeCode;
  final String? idCardPhotoPath;
  final InvalidValueReason? organizationError;
  final InvalidValueReason? brigadeCodeError;
  final bool submitting;
  final bool submitted;
  final bool failed;
  final bool cameraFailed;

  bool get idCardScanned => idCardPhotoPath != null;

  BrigadeCredentialState copyWith({
    String? organization,
    String? brigadeCode,
    String? Function()? idCardPhotoPath,
    InvalidValueReason? Function()? organizationError,
    InvalidValueReason? Function()? brigadeCodeError,
    bool? submitting,
    bool? submitted,
    bool? failed,
    bool? cameraFailed,
  }) => BrigadeCredentialState(
    organization: organization ?? this.organization,
    brigadeCode: brigadeCode ?? this.brigadeCode,
    idCardPhotoPath: idCardPhotoPath != null
        ? idCardPhotoPath()
        : this.idCardPhotoPath,
    organizationError: organizationError != null
        ? organizationError()
        : this.organizationError,
    brigadeCodeError: brigadeCodeError != null
        ? brigadeCodeError()
        : this.brigadeCodeError,
    submitting: submitting ?? this.submitting,
    submitted: submitted ?? this.submitted,
    failed: failed ?? this.failed,
    cameraFailed: cameraFailed ?? this.cameraFailed,
  );

  @override
  List<Object?> get props => [
    organization,
    brigadeCode,
    idCardPhotoPath,
    organizationError,
    brigadeCodeError,
    submitting,
    submitted,
    failed,
    cameraFailed,
  ];
}
