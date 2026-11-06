import 'package:equatable/equatable.dart';

import 'valueobjects.dart';

/// Status of the brigade credential (report 6.2.2: "Pendiente de
/// aprobación").
enum CredentialStatus {
  /// Saved on the device; the Command Center has not approved it yet.
  pendingApproval;

  static CredentialStatus fromName(String name) =>
      CredentialStatus.values.firstWhere((status) => status.name == name);
}

/// Credential a brigadist sends on A_02 to prove they belong to a response
/// organization.
///
/// The backend has no self-registration yet: brigade accounts are created by
/// the organization administrator. The credential stays on the device as
/// "Pendiente de aprobación" until the brigadist signs in with the account
/// the organization gives them (A_10).
final class BrigadeCredential extends Equatable {
  const BrigadeCredential({
    required this.organization,
    required this.brigadeCode,
    required this.submittedAt,
    this.idCardPhotoPath,
    this.status = CredentialStatus.pendingApproval,
  });

  final OrganizationName organization;
  final BrigadeCode brigadeCode;
  final DateTime submittedAt;

  /// Local path of the photo of the institutional ID card, if scanned.
  final String? idCardPhotoPath;
  final CredentialStatus status;

  bool get hasIdCardPhoto => idCardPhotoPath != null;

  @override
  List<Object?> get props => [
    organization,
    brigadeCode,
    submittedAt,
    idCardPhotoPath,
    status,
  ];
}
