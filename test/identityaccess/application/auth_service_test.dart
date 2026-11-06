import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/identityaccess/application/auth_service.dart';
import 'package:auxia_mobile/identityaccess/domain/model/brigade_credential.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/session.dart';
import 'package:auxia_mobile/identityaccess/domain/model/user_role.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../helpers/test_app.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 9);
  late InMemoryProfileRepository profiles;
  late InMemorySessionRepository sessions;
  late FakeAuthenticationGateway gateway;

  setUp(() {
    profiles = InMemoryProfileRepository();
    sessions = InMemorySessionRepository();
    gateway = FakeAuthenticationGateway(
      Right(brigadeSession(expiresAt: now.add(const Duration(hours: 8)))),
    );
  });

  AuthService service() =>
      AuthService(gateway, sessions, profiles, clock: () => now);

  Future<Either<SignInError, SignedIn>> signIn(AuthService auth) => auth.signIn(
    email: InstitutionalEmail(' M.Quispe@coerlima.gob.pe '),
    password: Password('secret-123'),
  );

  test('a brigadist signs in and gets a profile from the account', () async {
    final result = await signIn(service());

    final signedIn = result.getRight().toNullable()!;
    expect(gateway.lastEmail, 'm.quispe@coerlima.gob.pe');
    expect(signedIn.profile.role, UserRole.brigadist);
    expect(signedIn.profile.fullName.value, 'Cap. M. Quispe');
    expect(signedIn.profile.phone, isNull);
    expect(sessions.session, signedIn.session);
    expect(profiles.profile, signedIn.profile);
  });

  test('keeps the phone and credential of a registered brigadist', () async {
    profiles.profile =
        LocalProfile.register(
          fullName: FullName('Mario Quispe'),
          phone: PhoneNumber('987654321'),
          role: UserRole.brigadist,
          now: now,
        ).withCredential(
          BrigadeCredential(
            organization: OrganizationName('Defensa Civil'),
            brigadeCode: BrigadeCode('BRG-ALFA-07'),
            submittedAt: now,
          ),
        );

    final result = await signIn(service());

    final profile = result.getRight().toNullable()!.profile;
    expect(profile.fullName.value, 'Cap. M. Quispe');
    expect(profile.phone!.value, '987654321');
    expect(profile.credential!.brigadeCode.value, 'BRG-ALFA-07');
  });

  test('rejects accounts that are not field brigades', () async {
    gateway.result = Right(brigadeSession(role: AccountRole.authority));

    final result = await signIn(service());

    expect(
      result.getLeft().toNullable(),
      const SignInError(SignInErrorKind.notFieldBrigade),
    );
    expect(sessions.session, isNull);
  });

  test('passes on the generic message of rejected credentials', () async {
    gateway.result = const Left(
      UnauthorizedFailure('Credenciales no válidas.'),
    );

    final result = await signIn(service());

    expect(
      result.getLeft().toNullable(),
      const SignInError(SignInErrorKind.rejected, 'Credenciales no válidas.'),
    );
  });

  test('tells that the first sign-in needs signal', () async {
    gateway.result = const Left(NetworkFailure());

    final result = await signIn(service());

    expect(result.getLeft().toNullable()!.kind, SignInErrorKind.noConnection);
  });

  test('gives the token only while the session is valid', () async {
    sessions.session = brigadeSession(
      expiresAt: now.add(const Duration(minutes: 1)),
    );
    expect(await service().accessToken(), 'token-123');

    sessions.session = brigadeSession(expiresAt: now);
    expect(await service().accessToken(), isNull);
    expect(await service().currentSession(), isNotNull);
  });

  test('signing out forgets the session', () async {
    final auth = service();
    await signIn(auth);

    await auth.signOut();

    expect(sessions.session, isNull);
    expect(await auth.accessToken(), isNull);
  });
}
