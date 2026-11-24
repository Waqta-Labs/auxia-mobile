import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/model/session.dart';
import '../../domain/repositories/session_repository.dart';

/// Keeps the session token in the encrypted storage of the device.
class SecureSessionRepository implements SessionRepository {
  SecureSessionRepository(this._storage);

  static const String _key = 'auxia.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, Object?>;
    return Session(
      token: json['token']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String),
      userId: json['userId']! as String,
      organizationId: json['organizationId']! as String,
      role: AccountRole.fromCode(json['role']! as String),
      fullName: json['fullName']! as String,
    );
  }

  @override
  Future<void> save(Session session) => _storage.write(
    key: _key,
    value: jsonEncode({
      'token': session.token,
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
      'userId': session.userId,
      'organizationId': session.organizationId,
      'role': session.role.code,
      'fullName': session.fullName,
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
