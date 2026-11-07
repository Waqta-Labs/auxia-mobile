import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'valueobjects.dart';

/// Status of the brigade credential (report 6.2.2: "Pendiente de
/// aprobación"), as the administrator of the organization decides it.
enum CredentialStatus {
  /// Sent or waiting to be sent; the administrator has not decided yet.
  pendingApproval,

  /// Approved: the phone signs in with its device secret (plan D3).
  approved,

  /// Rejected, with the reason of the administrator.
  rejected;

  static CredentialStatus fromName(String name) =>
      CredentialStatus.values.firstWhere((status) => status.name == name);
}

/// Credential a brigadist sends on A_02 to prove they belong to a response
/// organization (plan D3).
///
/// The phone generates [registrationId] and [deviceSecret]. Once the
/// administrator approves the credential, the secret is the password of the
/// brigadist account: the app signs in with it, without e-mail or password.
/// The profile that holds it lives in the secure storage of the device.
final class BrigadeCredential extends Equatable {
  const BrigadeCredential({
    required this.registrationId,
    required this.deviceSecret,
    required this.organization,
    required this.brigadeCode,
    required this.submittedAt,
    this.idCardPhotoPath,
    this.status = CredentialStatus.pendingApproval,
    this.rejectionReason,
  });

  /// New credential with a fresh registration id and device secret.
  factory BrigadeCredential.create({
    required OrganizationName organization,
    required BrigadeCode brigadeCode,
    required DateTime now,
    String? idCardPhotoPath,
    Random? random,
  }) => BrigadeCredential(
    registrationId: const Uuid().v4(),
    deviceSecret: newDeviceSecret(random),
    organization: organization,
    brigadeCode: brigadeCode,
    submittedAt: now,
    idCardPhotoPath: idCardPhotoPath,
  );

  final String registrationId;

  /// 32 random bytes in base64 (44 characters).
  final String deviceSecret;
  final OrganizationName organization;
  final BrigadeCode brigadeCode;
  final DateTime submittedAt;

  /// Local path of the photo of the institutional ID card, if scanned.
  final String? idCardPhotoPath;
  final CredentialStatus status;
  final String? rejectionReason;

  bool get hasIdCardPhoto => idCardPhotoPath != null;

  bool get isApproved => status == CredentialStatus.approved;

  bool get isPending => status == CredentialStatus.pendingApproval;

  BrigadeCredential withStatus(CredentialStatus status, {String? reason}) =>
      BrigadeCredential(
        registrationId: registrationId,
        deviceSecret: deviceSecret,
        organization: organization,
        brigadeCode: brigadeCode,
        submittedAt: submittedAt,
        idCardPhotoPath: idCardPhotoPath,
        status: status,
        rejectionReason: status == CredentialStatus.rejected ? reason : null,
      );

  /// A secret the backend accepts: 32 random bytes in base64.
  static String newDeviceSecret([Random? random]) {
    final source = random ?? Random.secure();
    return base64Encode([for (var i = 0; i < 32; i++) source.nextInt(256)]);
  }

  @override
  List<Object?> get props => [
    registrationId,
    deviceSecret,
    organization,
    brigadeCode,
    submittedAt,
    idCardPhotoPath,
    status,
    rejectionReason,
  ];
}
