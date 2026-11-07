import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../../core/sync/outbox_item.dart';
import '../../core/sync/sync_engine.dart';
import '../domain/model/brigade_credential.dart';
import '../domain/model/local_profile.dart';
import '../domain/model/session.dart';
import '../domain/repositories/brigade_registration_gateway.dart';
import '../domain/repositories/profile_repository.dart';
import 'auth_service.dart';
import 'profile_service.dart';

/// Sends the credential of A_02 when the outbox syncs. The registration id
/// makes it idempotent. A code the backend does not know (404) or a photo it
/// rejects (409, 422) cannot succeed later: the credential becomes rejected
/// with that message and leaves the queue.
class BrigadeRegistrationHandler implements OutboxHandler {
  BrigadeRegistrationHandler(this._profiles, this._service, this._gateway);

  final ProfileRepository _profiles;
  final ProfileService _service;
  final BrigadeRegistrationGateway _gateway;

  @override
  String get type => IdentityOutboxTypes.brigadeRegistration;

  @override
  Future<Either<Failure, Unit>> send(OutboxItem item) async {
    final profile = await _profiles.load();
    final credential = profile?.credential;
    if (profile == null ||
        credential == null ||
        credential.registrationId != item.id ||
        !credential.isPending) {
      return const Right(unit);
    }
    final result = await _gateway.submit(
      credential,
      fullName: profile.fullName.value,
      phone: profile.phone?.value ?? '',
    );
    if (result case Left(
      value: final failure,
    ) when failure is NotFoundFailure || failure is ValidationFailure) {
      await _service.updateCredential(
        CredentialStatus.rejected,
        reason: failure.message,
      );
    }
    return result;
  }
}

/// The profile after asking for the decision, and the session when the
/// approved credential signed in.
final class RegistrationCheck extends Equatable {
  const RegistrationCheck(this.profile, {this.session});

  final LocalProfile profile;
  final Session? session;

  @override
  List<Object?> get props => [profile, session];
}

/// Follows the credential of A_02 until the administrator decides
/// (plan D3): pending → approved, then signs in with the device secret.
class BrigadeRegistrationService {
  BrigadeRegistrationService(
    this._profiles,
    this._service,
    this._gateway,
    this._auth, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ProfileRepository _profiles;
  final ProfileService _service;
  final BrigadeRegistrationGateway _gateway;
  final AuthService _auth;
  final DateTime Function() _clock;

  /// Asks for the decision while it is pending and, once approved, opens a
  /// session if there is no valid one. Null when there is nothing to follow
  /// (no credential) or the backend could not be reached.
  Future<RegistrationCheck?> refresh() async {
    var profile = await _profiles.load();
    var credential = profile?.credential;
    if (profile == null || credential == null) return null;

    if (credential.isPending) {
      final decision = await _gateway.status(credential);
      // 404: not sent yet, or sent from another device; nothing to update.
      if (decision case Right(
        value: final value,
      ) when value.status != CredentialStatus.pendingApproval) {
        profile = await _service.updateCredential(
          value.status,
          reason: value.reason,
        );
        credential = profile?.credential;
      }
    }
    if (profile == null || credential == null) return null;
    if (!credential.isApproved) return RegistrationCheck(profile);

    final session = await _auth.currentSession();
    if (session != null && !session.isExpiredAt(_clock())) {
      return RegistrationCheck(profile, session: session);
    }
    final signedIn = await _auth.signInWithDevice(credential);
    return switch (signedIn) {
      Right(value: final value) => RegistrationCheck(
        value.profile,
        session: value.session,
      ),
      Left() => RegistrationCheck(profile),
    };
  }
}
