import 'package:equatable/equatable.dart';

import 'brigade_credential.dart';
import 'user_role.dart';
import 'valueobjects.dart';

/// Profile created on the device on the registration screen (A_01).
///
/// It never leaves the device by itself ("Tus datos se guardan en tu
/// dispositivo"). A brigadist also keeps the credential sent for approval.
final class LocalProfile extends Equatable {
  const LocalProfile({
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.phone,
    this.credential,
  });

  /// Registers a new profile with the chosen role.
  factory LocalProfile.register({
    required FullName fullName,
    required PhoneNumber phone,
    required UserRole role,
    required DateTime now,
  }) => LocalProfile(
    fullName: fullName,
    phone: phone,
    role: role,
    createdAt: now,
  );

  /// Brigadist who skipped A_01 and signed in with the institutional
  /// account (A_10): the name comes from the account, without phone.
  factory LocalProfile.fromInstitutionalAccount({
    required FullName fullName,
    required DateTime now,
  }) => LocalProfile(
    fullName: fullName,
    role: UserRole.brigadist,
    createdAt: now,
  );

  final FullName fullName;
  final PhoneNumber? phone;
  final UserRole role;
  final DateTime createdAt;
  final BrigadeCredential? credential;

  bool get isBrigadist => role == UserRole.brigadist;

  /// Same profile with the name of the institutional account.
  LocalProfile renamed(FullName name) => LocalProfile(
    fullName: name,
    phone: phone,
    role: role,
    createdAt: createdAt,
    credential: credential,
  );

  /// Attaches the brigade credential (A_02). Only a brigadist has one.
  LocalProfile withCredential(BrigadeCredential credential) {
    if (!isBrigadist) {
      throw StateError('Only a brigadist can send a brigade credential.');
    }
    return LocalProfile(
      fullName: fullName,
      phone: phone,
      role: role,
      createdAt: createdAt,
      credential: credential,
    );
  }

  @override
  List<Object?> get props => [fullName, phone, role, createdAt, credential];
}
