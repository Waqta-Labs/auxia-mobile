import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../domain/model/local_profile.dart';
import '../domain/model/session.dart';
import '../domain/model/user_role.dart';
import '../domain/model/valueobjects.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/repositories/session_repository.dart';

/// Why a sign-in did not succeed.
enum SignInErrorKind {
  /// Wrong e-mail or password, or a locked account. The backend sends one
  /// generic message that does not reveal which field failed (US-21).
  rejected,

  /// The account exists but is not a field brigade account.
  notFieldBrigade,

  /// No connection: the first sign-in needs signal.
  noConnection,

  unexpected,
}

class SignInError extends Equatable {
  const SignInError(this.kind, [this.message = '']);

  final SignInErrorKind kind;

  /// Message of the backend, already in the language of the app.
  final String message;

  @override
  List<Object> get props => [kind, message];
}

/// Result of a successful sign-in: the session and the brigadist profile.
class SignedIn extends Equatable {
  const SignedIn(this.profile, this.session);

  final LocalProfile profile;
  final Session session;

  @override
  List<Object> get props => [profile, session];
}

/// Sign-in of brigadists with the institutional account (A_10, US-21).
class AuthService {
  AuthService(
    this._gateway,
    this._sessions,
    this._profiles, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AuthenticationGateway _gateway;
  final SessionRepository _sessions;
  final ProfileRepository _profiles;
  final DateTime Function() _clock;

  Session? _cached;

  Future<Either<SignInError, SignedIn>> signIn({
    required InstitutionalEmail email,
    required Password password,
  }) async {
    final result = await _gateway.signIn(
      email: email.value,
      password: password.value,
    );
    final Session session;
    switch (result) {
      case Left(value: final failure):
        return Left(_toError(failure));
      case Right(value: final signedIn):
        session = signedIn;
    }
    if (session.role != AccountRole.fieldBrigade) {
      return const Left(SignInError(SignInErrorKind.notFieldBrigade));
    }
    try {
      final profile = await _brigadistProfileFor(session);
      await _profiles.save(profile);
      await _sessions.save(session);
      _cached = session;
      return Right(SignedIn(profile, session));
    } on Exception catch (error) {
      return Left(SignInError(SignInErrorKind.unexpected, '$error'));
    }
  }

  /// The saved session, even if it expired: the app keeps working offline.
  Future<Session?> currentSession() async {
    try {
      return _cached ??= await _sessions.load();
    } on Exception {
      return null;
    }
  }

  /// Bearer token for the API, or null without a valid session.
  Future<String?> accessToken() async {
    final session = await currentSession();
    if (session == null || session.isExpiredAt(_clock())) return null;
    return session.token;
  }

  Future<void> signOut() async {
    _cached = null;
    await _sessions.clear();
  }

  /// Keeps the brigadist's own data (phone, credential) and takes the name
  /// of the institutional account.
  Future<LocalProfile> _brigadistProfileFor(Session session) async {
    final name = FullName(session.fullName);
    final existing = await _profiles.load();
    if (existing != null && existing.role == UserRole.brigadist) {
      return existing.renamed(name);
    }
    return LocalProfile.fromInstitutionalAccount(fullName: name, now: _clock());
  }

  static SignInError _toError(Failure failure) => switch (failure) {
    UnauthorizedFailure() || ForbiddenFailure() || ValidationFailure() =>
      SignInError(SignInErrorKind.rejected, failure.message),
    NetworkFailure() => const SignInError(SignInErrorKind.noConnection),
    _ => SignInError(SignInErrorKind.unexpected, failure.message),
  };
}
