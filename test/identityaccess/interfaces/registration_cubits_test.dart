import 'package:auxia_mobile/identityaccess/application/profile_service.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/user_role.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:auxia_mobile/identityaccess/interfaces/pages/brigade_credential/brigade_credential_cubit.dart';
import 'package:auxia_mobile/identityaccess/interfaces/pages/registration/registration_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  group('RegistrationCubit (A_01)', () {
    late InMemoryProfileRepository repository;
    late List<LocalProfile> registered;

    setUp(() {
      repository = InMemoryProfileRepository();
      registered = [];
    });

    RegistrationCubit build() => RegistrationCubit(
      ProfileService(repository),
      onRegistered: registered.add,
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'shows the errors of an empty form',
      build: build,
      act: (cubit) => cubit.submit(),
      expect: () => [
        const RegistrationState(
          nameError: InvalidValueReason.nameRequired,
          phoneError: InvalidValueReason.phoneRequired,
        ),
      ],
      verify: (_) => expect(repository.profile, isNull),
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'saves a citizen and notifies the app',
      build: build,
      act: (cubit) async {
        cubit
          ..nameChanged('María Quispe')
          ..phoneChanged('+51 987 654 321');
        await cubit.submit();
      },
      skip: 2,
      expect: () => [
        isA<RegistrationState>().having(
          (s) => s.submitting,
          'submitting',
          true,
        ),
        isA<RegistrationState>().having(
          (s) => s.outcome,
          'outcome',
          RegistrationOutcome.citizenRegistered,
        ),
      ],
      verify: (_) {
        expect(repository.profile!.role, UserRole.citizen);
        expect(registered, hasLength(1));
      },
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'sends a brigadist to the credential step without saving yet',
      build: build,
      act: (cubit) async {
        cubit
          ..nameChanged('Cap. M. Quispe')
          ..phoneChanged('987654321')
          ..roleSelected(UserRole.brigadist);
        await cubit.submit();
      },
      skip: 3,
      expect: () => [
        isA<RegistrationState>().having(
          (s) => s.outcome,
          'outcome',
          RegistrationOutcome.continueToCredential,
        ),
      ],
      verify: (cubit) {
        expect(repository.profile, isNull);
        expect(cubit.pending!.fullName.value, 'Cap. M. Quispe');
      },
    );
  });

  group('BrigadeCredentialCubit (A_02)', () {
    late InMemoryProfileRepository repository;
    late List<LocalProfile> registered;
    final pending = PendingRegistration(
      fullName: FullName('Cap. M. Quispe'),
      phone: PhoneNumber('987654321'),
    );

    setUp(() {
      repository = InMemoryProfileRepository();
      registered = [];
    });

    BrigadeCredentialCubit build({CaptureIdCard? capture}) =>
        BrigadeCredentialCubit(
          ProfileService(repository),
          pending: pending,
          captureIdCard: capture ?? () async => '/data/id_card.jpg',
          onRegistered: registered.add,
        );

    blocTest<BrigadeCredentialCubit, BrigadeCredentialState>(
      'requires the organization and the brigade code',
      build: build,
      act: (cubit) => cubit.submit(),
      expect: () => [
        const BrigadeCredentialState(
          organizationError: InvalidValueReason.organizationRequired,
          brigadeCodeError: InvalidValueReason.brigadeCodeRequired,
        ),
      ],
    );

    blocTest<BrigadeCredentialCubit, BrigadeCredentialState>(
      'keeps the photo of the scanned id card',
      build: build,
      act: (cubit) => cubit.scanIdCard(),
      expect: () => [
        const BrigadeCredentialState(idCardPhotoPath: '/data/id_card.jpg'),
      ],
    );

    blocTest<BrigadeCredentialCubit, BrigadeCredentialState>(
      'reports a camera that cannot open',
      build: () => build(capture: () async => throw Exception('no camera')),
      act: (cubit) => cubit.scanIdCard(),
      expect: () => [const BrigadeCredentialState(cameraFailed: true)],
    );

    blocTest<BrigadeCredentialCubit, BrigadeCredentialState>(
      'saves the brigadist with the credential pending approval',
      build: build,
      act: (cubit) async {
        cubit
          ..organizationChanged('Defensa Civil · Región Lima')
          ..brigadeCodeChanged('brg-alfa-07');
        await cubit.submit();
      },
      skip: 3,
      expect: () => [
        isA<BrigadeCredentialState>().having(
          (s) => s.submitted,
          'submitted',
          true,
        ),
      ],
      verify: (_) {
        final profile = repository.profile!;
        expect(profile.role, UserRole.brigadist);
        expect(profile.credential!.brigadeCode.value, 'BRG-ALFA-07');
        expect(registered.single, profile);
      },
    );
  });
}
