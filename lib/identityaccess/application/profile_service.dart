import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../domain/model/brigade_credential.dart';
import '../domain/model/local_profile.dart';
import '../domain/model/user_role.dart';
import '../domain/model/valueobjects.dart';
import '../domain/repositories/profile_repository.dart';

/// Use cases of the registration flow (A_01 and A_02).
class ProfileService {
  ProfileService(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ProfileRepository _repository;
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
          BrigadeCredential(
            organization: organization,
            brigadeCode: brigadeCode,
            submittedAt: now,
            idCardPhotoPath: idCardPhotoPath,
          ),
        );
    await _repository.save(profile);
    return profile;
  });

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
