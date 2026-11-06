import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/identityaccess/application/auth_service.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:auxia_mobile/identityaccess/interfaces/pages/sign_in/sign_in_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../helpers/test_app.dart';

void main() {
  late FakeAuthenticationGateway gateway;
  late List<SignedIn> signedIn;

  setUp(() {
    gateway = FakeAuthenticationGateway();
    signedIn = [];
  });

  SignInCubit build() => SignInCubit(
    AuthService(
      gateway,
      InMemorySessionRepository(),
      InMemoryProfileRepository(),
    ),
    onSignedIn: signedIn.add,
  );

  blocTest<SignInCubit, SignInState>(
    'validates the e-mail and the password',
    build: build,
    act: (cubit) async {
      cubit.emailChanged('m.quispe');
      await cubit.submit();
    },
    skip: 1,
    expect: () => [
      const SignInState(
        email: 'm.quispe',
        emailError: InvalidValueReason.emailInvalid,
        passwordError: InvalidValueReason.passwordRequired,
      ),
    ],
  );

  blocTest<SignInCubit, SignInState>(
    'shows the error of rejected credentials',
    build: () {
      gateway.result = const Left(
        UnauthorizedFailure('Credenciales no válidas.'),
      );
      return build();
    },
    act: (cubit) async {
      cubit
        ..emailChanged('m.quispe@coerlima.gob.pe')
        ..passwordChanged('wrong');
      await cubit.submit();
    },
    skip: 3,
    expect: () => [
      isA<SignInState>().having(
        (s) => s.error,
        'error',
        const SignInError(SignInErrorKind.rejected, 'Credenciales no válidas.'),
      ),
    ],
    verify: (_) => expect(signedIn, isEmpty),
  );

  blocTest<SignInCubit, SignInState>(
    'clears the password and notifies the app after signing in',
    build: build,
    act: (cubit) async {
      cubit
        ..emailChanged('m.quispe@coerlima.gob.pe')
        ..passwordChanged('secret-123');
      await cubit.submit();
    },
    skip: 3,
    expect: () => [
      isA<SignInState>()
          .having((s) => s.password, 'password', isEmpty)
          .having((s) => s.submitting, 'submitting', isFalse),
    ],
    verify: (_) => expect(signedIn, hasLength(1)),
  );
}
