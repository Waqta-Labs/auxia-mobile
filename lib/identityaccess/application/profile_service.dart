import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../../core/sync/outbox_repository.dart';
import '../domain/model/brigade_credential.dart';
import '../domain/model/local_profile.dart';
import '../domain/model/user_role.dart';
import '../domain/model/valueobjects.dart';
import '../domain/repositories/profile_repository.dart';

/// Outbox types of Identity and Access.
abstract final class IdentityOutboxTypes {
  /// The brigade credential of A_02, sent for approval (plan D3).
  static const String brigadeRegistration = 'brigade_registration';
}

/// Use cases of the registration flow (A_01 and A_02).
class ProfileService {
  ProfileService(this._repository, {this._outbox, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ProfileRepository _repository;
  final OutboxRepository? _outbox;
  final DateTime Function() _clock;

  Future<Either<Failure, LocalProfile?>> currentProfile() =>
      _guard(_repository.load);

  /// A_01 with the Ciudadano role: the profile is ready to use.
  Future<Either<Failure, LocalProfile>> registerCitizen({
    required FullName fullName,
    required PhoneNumber phone,
  }) => _guard(() async {
    final profile = LocalProfile.register(
      fullName: fullName,
      phone: phone,
      role: UserRole.citizen,
      now: _clock(),
    );
    await _repository.save(profile);
    return profile;
  });

  /// A_02: saves the brigadist with the credential pending approval.
  Future<Either<Failure, LocalProfile>> registerBrigadist({
    required FullName fullName,
    required PhoneNumber phone,
    required OrganizationName organization,
    required BrigadeCode brigadeCode,
    String? idCardPhotoPath,
  }) => _guard(() async {
    final now = _clock();
    final profile =
        LocalProfile.register(
          fullName: fullName,
          phone: phone,
          role: UserRole.brigadist,
          now: now,
        ).withCredential(
          BrigadeCredential.create(
            organization: organization,
            brigadeCode: brigadeCode,
            now: now,
            idCardPhotoPath: idCardPhotoPath,
          ),
        );
    await _repository.save(profile);
    // Sent to the backend by the sync queue, even without signal now.
    await _outbox?.enqueue(
      type: IdentityOutboxTypes.brigadeRegistration,
      payload: const {},
      id: profile.credential!.registrationId,
    );
    return profile;
  });

  /// Saves the profile with the credential in its new [status].
  Future<LocalProfile?> updateCredential(
    CredentialStatus status, {
    String? reason,
  }) async {
    final profile = await _repository.load();
    final credential = profile?.credential;
    if (profile == null || credential == null) return null;
    final updated = profile.withCredential(
      credential.withStatus(status, reason: reason),
    );
    await _repository.save(updated);
    return updated;
  }

  /// "Cambiar de rol": forgets the profile so the user registers again.
  Future<Either<Failure, Unit>> resetProfile() => _guard(() async {
    await _repository.clear();
    return unit;
  });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on Exception catch (error) {
      return Left(UnexpectedFailure(error.toString()));
    }
  }
}
