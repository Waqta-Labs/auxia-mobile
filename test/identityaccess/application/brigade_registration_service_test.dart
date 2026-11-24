import 'dart:convert';

import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/identityaccess/application/auth_service.dart';
import 'package:auxia_mobile/identityaccess/application/brigade_registration_service.dart';
import 'package:auxia_mobile/identityaccess/application/profile_service.dart';
import 'package:auxia_mobile/identityaccess/domain/model/brigade_credential.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/user_role.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:auxia_mobile/identityaccess/domain/repositories/brigade_registration_gateway.dart';
import 'package:auxia_mobile/identityaccess/infrastructure/persistence/secure_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

class _FakeRegistrationGateway implements BrigadeRegistrationGateway {
  Either<Failure, Unit> submitResult = const Right(unit);
  Either<Failure, RegistrationDecision> decision = const Right(
    RegistrationDecision(CredentialStatus.pendingApproval),
  );
  final List<(String, String, String)> submitted = [];

  @override
  Future<Either<Failure, Unit>> submit(
    BrigadeCredential credential, {
    required String fullName,
    required String phone,
  }) async {
    submitted.add((credential.registrationId, fullName, phone));
    return submitResult;
  }

  @override
  Future<Either<Failure, RegistrationDecision>> status(
    BrigadeCredential credential,
  ) async => decision;
}

void main() {
  final now = DateTime(2026, 11, 7, 9, 41);
  late Database db;
  late OutboxRepository outbox;
  late InMemoryProfileRepository profiles;
  late InMemorySessionRepository sessions;
  late ProfileService profileService;
  late FakeAuthenticationGateway authGateway;
  late _FakeRegistrationGateway gateway;

  setUp(() async {
    db = await openTestDatabase();
    outbox = OutboxRepository(db);
    profiles = InMemoryProfileRepository();
    sessions = InMemorySessionRepository();
    profileService = ProfileService(profiles, outbox: outbox, clock: () => now);
    authGateway = FakeAuthenticationGateway();
    gateway = _FakeRegistrationGateway();
  });

  tearDown(() => db.close());

  AuthService auth() =>
      AuthService(authGateway, sessions, profiles, clock: () => now);

  BrigadeRegistrationService service() => BrigadeRegistrationService(
    profiles,
    profileService,
    gateway,
    auth(),
    clock: () => now,
  );

  Future<LocalProfile> register() async =>
      (await profileService.registerBrigadist(
        fullName: FullName('Miguel Quispe'),
        phone: PhoneNumber('987654321'),
        organization: OrganizationName('Defensa Civil'),
        brigadeCode: BrigadeCode('BRG-ALFA-07'),
      )).getRight().toNullable()!;

  group('BrigadeCredential', () {
    test('the phone creates its id and a 32-byte secret', () {
      final credential = BrigadeCredential.create(
        organization: OrganizationName('Defensa Civil'),
        brigadeCode: BrigadeCode('BRG-ALFA-07'),
        now: now,
      );

      expect(credential.registrationId, hasLength(36));
      expect(base64Decode(credential.deviceSecret), hasLength(32));
      expect(credential.deviceSecret.length, inInclusiveRange(32, 64));
      expect(credential.isPending, isTrue);
    });

    test('the secure profile keeps the ids, the status and the reason', () {
      final profile =
          LocalProfile.register(
            fullName: FullName('Miguel Quispe'),
            phone: PhoneNumber('987654321'),
            role: UserRole.brigadist,
            now: now,
          ).withCredential(
            BrigadeCredential.create(
              organization: OrganizationName('Defensa Civil'),
              brigadeCode: BrigadeCode('BRG-ALFA-07'),
              now: now,
            ).withStatus(CredentialStatus.rejected, reason: 'Carnet ilegible'),
          );

      expect(ProfileJson.fromJson(profile.toJson()), profile);
    });

    test('a credential saved before the endpoint gets new ids', () {
      final restored = ProfileJson.fromJson({
        'fullName': 'Miguel Quispe',
        'phone': '987654321',
        'role': 'brigadist',
        'createdAt': now.toIso8601String(),
        'credential': {
          'organization': 'Defensa Civil',
          'brigadeCode': 'BRG-ALFA-07',
          'submittedAt': now.toIso8601String(),
          'status': 'pendingApproval',
        },
      });

      expect(restored.credential!.registrationId, isNotEmpty);
      expect(restored.credential!.deviceSecret, isNotEmpty);
    });
  });

  test('registering on A_02 queues the credential by its id', () async {
    final profile = await register();

    final item = await outbox.find(profile.credential!.registrationId);
    expect(item!.type, IdentityOutboxTypes.brigadeRegistration);
  });

  group('BrigadeRegistrationHandler', () {
    test('sends the credential with the name and phone of A_01', () async {
      final profile = await register();
      final item = (await outbox.find(profile.credential!.registrationId))!;

      final result = await BrigadeRegistrationHandler(
        profiles,
        profileService,
        gateway,
      ).send(item);

      expect(result.isRight(), isTrue);
      expect(gateway.submitted.single, (
        profile.credential!.registrationId,
        'Miguel Quispe',
        '987654321',
      ));
    });

    test('an unknown brigade code rejects the credential', () async {
      final profile = await register();
      gateway.submitResult = const Left(
        NotFoundFailure('El código de brigada no existe.'),
      );

      final result = await BrigadeRegistrationHandler(
        profiles,
        profileService,
        gateway,
      ).send((await outbox.find(profile.credential!.registrationId))!);

      expect(result.getLeft().toNullable()!.isRetryable, isFalse);
      final credential = (await profiles.load())!.credential!;
      expect(credential.status, CredentialStatus.rejected);
      expect(credential.rejectionReason, 'El código de brigada no existe.');
    });

    test('without signal the credential stays queued', () async {
      final profile = await register();
      gateway.submitResult = const Left(NetworkFailure());

      final result = await BrigadeRegistrationHandler(
        profiles,
        profileService,
        gateway,
      ).send((await outbox.find(profile.credential!.registrationId))!);

      expect(result.getLeft().toNullable()!.isRetryable, isTrue);
      expect((await profiles.load())!.credential!.isPending, isTrue);
    });
  });

  group('BrigadeRegistrationService', () {
    test('a pending credential stays pending', () async {
      await register();

      final check = await service().refresh();

      expect(check!.profile.credential!.isPending, isTrue);
      expect(check.session, isNull);
      expect(authGateway.deviceSignIns, isEmpty);
    });

    test('once approved, it signs in with the device secret', () async {
      final profile = await register();
      gateway.decision = const Right(
        RegistrationDecision(CredentialStatus.approved),
      );

      final check = await service().refresh();

      expect(check!.profile.credential!.isApproved, isTrue);
      expect(check.session, isNotNull);
      expect(
        authGateway.deviceSignIns.single,
        profile.credential!.registrationId,
      );
      expect(await sessions.load(), isNotNull);
    });

    test('a rejection keeps the reason of the administrator', () async {
      await register();
      gateway.decision = const Right(
        RegistrationDecision(
          CredentialStatus.rejected,
          reason: 'No pertenece a la brigada',
        ),
      );

      final check = await service().refresh();

      expect(check!.profile.credential!.status, CredentialStatus.rejected);
      expect(
        check.profile.credential!.rejectionReason,
        'No pertenece a la brigada',
      );
      expect(check.session, isNull);
    });

    test('without signal nothing changes', () async {
      await register();
      gateway.decision = const Left(NetworkFailure());

      final check = await service().refresh();

      expect(check!.profile.credential!.isPending, isTrue);
    });
  });

  group('AuthService renewal', () {
    test('an expired session of an approved credential is renewed', () async {
      await register();
      await profileService.updateCredential(CredentialStatus.approved);
      sessions.session = brigadeSession(
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      authGateway.result = Right(
        brigadeSession(expiresAt: now.add(const Duration(hours: 8))),
      );

      final token = await auth().accessToken();

      expect(token, 'token-123');
      expect(authGateway.deviceSignIns, hasLength(1));
    });

    test('a brigadist who signed out is not signed in again', () async {
      await register();
      await profileService.updateCredential(CredentialStatus.approved);

      final token = await auth().accessToken();

      expect(token, isNull);
      expect(authGateway.deviceSignIns, isEmpty);
    });
  });
}
