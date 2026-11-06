import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/identityaccess/application/profile_service.dart';
import 'package:auxia_mobile/identityaccess/domain/model/brigade_credential.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/user_role.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:auxia_mobile/identityaccess/domain/repositories/profile_repository.dart';
import 'package:auxia_mobile/identityaccess/infrastructure/persistence/secure_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

class _BrokenRepository implements ProfileRepository {
  @override
  Future<void> clear() async => throw Exception('keystore unavailable');

  @override
  Future<LocalProfile?> load() async => throw Exception('keystore unavailable');

  @override
  Future<void> save(LocalProfile profile) async =>
      throw Exception('keystore unavailable');
}

void main() {
  final now = DateTime(2026, 11, 6, 9, 41);

  test('registers a citizen and keeps it on the device', () async {
    final repository = InMemoryProfileRepository();
    final service = ProfileService(repository, clock: () => now);

    final result = await service.registerCitizen(
      fullName: FullName('María Quispe'),
      phone: PhoneNumber('+51 987 654 321'),
    );

    final profile = result.getRight().toNullable()!;
    expect(profile.role, UserRole.citizen);
    expect(profile.credential, isNull);
    expect(profile.createdAt, now);
    expect(repository.profile, profile);
  });

  test('registers a brigadist with the credential pending approval', () async {
    final repository = InMemoryProfileRepository();
    final service = ProfileService(repository, clock: () => now);

    final result = await service.registerBrigadist(
      fullName: FullName('Cap. M. Quispe'),
      phone: PhoneNumber('987654321'),
      organization: OrganizationName('Defensa Civil · Región Lima'),
      brigadeCode: BrigadeCode('BRG-ALFA-07'),
      idCardPhotoPath: '/data/credentials/id_card.jpg',
    );

    final profile = result.getRight().toNullable()!;
    expect(profile.role, UserRole.brigadist);
    expect(profile.credential!.status, CredentialStatus.pendingApproval);
    expect(profile.credential!.hasIdCardPhoto, isTrue);
    expect(repository.profile, profile);
  });

  test('forgets the profile to change role', () async {
    final repository = InMemoryProfileRepository();
    final service = ProfileService(repository, clock: () => now);
    await service.registerCitizen(
      fullName: FullName('María Quispe'),
      phone: PhoneNumber('987654321'),
    );

    await service.resetProfile();

    expect((await service.currentProfile()).getRight().toNullable(), isNull);
  });

  test('turns storage errors into failures', () async {
    final service = ProfileService(_BrokenRepository());

    final result = await service.currentProfile();

    expect(result.getLeft().toNullable(), isA<UnexpectedFailure>());
  });

  test('a citizen cannot hold a brigade credential', () {
    final citizen = LocalProfile.register(
      fullName: FullName('María Quispe'),
      phone: PhoneNumber('987654321'),
      role: UserRole.citizen,
      now: now,
    );

    expect(
      () => citizen.withCredential(
        BrigadeCredential(
          organization: OrganizationName('Defensa Civil'),
          brigadeCode: BrigadeCode('BRG-01'),
          submittedAt: now,
        ),
      ),
      throwsStateError,
    );
  });

  test('the stored json restores the same profile', () {
    final profile =
        LocalProfile.register(
          fullName: FullName('Cap. M. Quispe'),
          phone: PhoneNumber('987654321'),
          role: UserRole.brigadist,
          now: now,
        ).withCredential(
          BrigadeCredential(
            organization: OrganizationName('Defensa Civil · Región Lima'),
            brigadeCode: BrigadeCode('BRG-ALFA-07'),
            submittedAt: now,
          ),
        );

    expect(ProfileJson.fromJson(profile.toJson()), profile);
  });
}
