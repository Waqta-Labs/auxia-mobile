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
    required this.phone,
    required this.role,
    required this.createdAt,
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

  final FullName fullName;
  final PhoneNumber phone;
  final UserRole role;
  final DateTime createdAt;
  final BrigadeCredential? credential;

  bool get isBrigadist => role == UserRole.brigadist;

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
