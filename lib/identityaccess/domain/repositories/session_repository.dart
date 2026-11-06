import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/session.dart';

/// Port to keep the session on the device.
abstract interface class SessionRepository {
  Future<Session?> load();

  Future<void> save(Session session);

  Future<void> clear();
}

/// Port to the sign-in of the backend (`POST /auth/sign-in`).
abstract interface class AuthenticationGateway {
  Future<Either<Failure, Session>> signIn({
    required String email,
    required String password,
  });
}
