import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/session.dart';

/// Port to keep the session on the device.
abstract interface class SessionRepository {
  Future<Session?> load();

  Future<void> save(Session session);

  Future<void> clear();
}

/// Port to the sign-in of the backend.
abstract interface class AuthenticationGateway {
  /// `POST /auth/sign-in`, accounts created by the administrator (A_10).
  Future<Either<Failure, Session>> signIn({
    required String email,
    required String password,
  });

  /// `POST /auth/device-sign-in`, brigadists approved from A_02 (plan D3).
  Future<Either<Failure, Session>> deviceSignIn({
    required String registrationId,
    required String deviceSecret,
  });
}
