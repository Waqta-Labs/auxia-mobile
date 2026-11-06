import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/model/brigade_credential.dart';
import '../../domain/model/local_profile.dart';
import '../../domain/model/user_role.dart';
import '../../domain/model/valueobjects.dart';
import '../../domain/repositories/profile_repository.dart';

/// Keeps the profile in the encrypted storage of the device (Android
/// Keystore, iOS Keychain), because it holds the name and phone number.
class SecureProfileRepository implements ProfileRepository {
  SecureProfileRepository(this._storage);

  static const String _key = 'auxia.profile.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<LocalProfile?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return ProfileJson.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  @override
  Future<void> save(LocalProfile profile) =>
      _storage.write(key: _key, value: jsonEncode(profile.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// JSON mapping of the profile, kept out of the domain model.
extension ProfileJson on LocalProfile {
  Map<String, Object?> toJson() => {
    'fullName': fullName.value,
    'phone': phone?.value,
    'role': role.name,
    'createdAt': createdAt.toIso8601String(),
    if (credential case final credential?)
      'credential': {
        'organization': credential.organization.value,
        'brigadeCode': credential.brigadeCode.value,
        'submittedAt': credential.submittedAt.toIso8601String(),
        'idCardPhotoPath': credential.idCardPhotoPath,
        'status': credential.status.name,
      },
  };

  static LocalProfile fromJson(Map<String, Object?> json) {
    final profile = LocalProfile(
      fullName: FullName(json['fullName']! as String),
      phone: switch (json['phone']) {
        final String phone => PhoneNumber(phone),
        _ => null,
      },
      role: UserRole.fromName(json['role']! as String),
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
    final credential = json['credential'] as Map<String, Object?>?;
    if (credential == null) return profile;
    return profile.withCredential(
      BrigadeCredential(
        organization: OrganizationName(credential['organization']! as String),
        brigadeCode: BrigadeCode(credential['brigadeCode']! as String),
        submittedAt: DateTime.parse(credential['submittedAt']! as String),
        idCardPhotoPath: credential['idCardPhotoPath'] as String?,
        status: CredentialStatus.fromName(credential['status']! as String),
      ),
    );
  }
}
