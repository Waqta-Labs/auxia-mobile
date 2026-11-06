import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../../../core/network/api_client.dart';
import '../../domain/model/session.dart';
import '../../domain/repositories/session_repository.dart';

/// `POST /api/v1/auth/sign-in` of the AuxIA backend.
class HttpAuthenticationGateway implements AuthenticationGateway {
  HttpAuthenticationGateway(this._client);

  final ApiClient _client;

  @override
  Future<Either<Failure, Session>> signIn({
    required String email,
    required String password,
  }) => _client.post(
    '/auth/sign-in',
    body: {'email': email, 'password': password},
    parse: (data) => authenticatedUserFromJson(data! as Map<String, Object?>),
  );
}

/// Maps `AuthenticatedUserResource` to the session of the domain.
///
/// `expiresAt` comes as a date-time in UTC without zone; it is read as UTC.
Session authenticatedUserFromJson(Map<String, Object?> json) {
  final rawExpiry = json['expiresAt']! as String;
  final expiresAt = DateTime.parse(
    rawExpiry.endsWith('Z') || rawExpiry.contains('+')
        ? rawExpiry
        : '${rawExpiry}Z',
  );
  return Session(
    token: json['token']! as String,
    expiresAt: expiresAt,
    userId: json['userId']! as String,
    organizationId: json['organizationId']! as String,
    role: AccountRole.fromCode(json['role']! as String),
    fullName: json['fullName']! as String,
  );
}
