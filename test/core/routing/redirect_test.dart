import 'package:auxia_mobile/core/routing/app_router.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/user_role.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:auxia_mobile/identityaccess/interfaces/profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

LocalProfile _profile(UserRole role) => LocalProfile.register(
  fullName: FullName('María Quispe'),
  phone: PhoneNumber('987654321'),
  role: role,
  now: DateTime(2026, 11, 6),
);

void main() {
  test('waits on the start screen while the profile loads', () {
    const state = ProfileState.loading();

    expect(redirectForProfile(state, AppRoutes.startup), isNull);
    expect(redirectForProfile(state, AppRoutes.citizenSos), AppRoutes.startup);
  });

  test('sends a new user to the registration', () {
    const state = ProfileState.absent();

    expect(
      redirectForProfile(state, AppRoutes.startup),
      AppRoutes.registration,
    );
    expect(redirectForProfile(state, AppRoutes.brigadeCredential), isNull);
  });

  test('a citizen lands on SOS and stays in the citizen sections', () {
    final state = ProfileState.present(_profile(UserRole.citizen));

    expect(
      redirectForProfile(state, AppRoutes.registration),
      AppRoutes.citizenSos,
    );
    expect(redirectForProfile(state, AppRoutes.citizenReports), isNull);
    expect(
      redirectForProfile(state, AppRoutes.brigadeMissions),
      AppRoutes.citizenSos,
    );
  });

  test('a brigadist lands on missions and stays in the brigade sections', () {
    final state = ProfileState.present(_profile(UserRole.brigadist));

    expect(
      redirectForProfile(state, AppRoutes.startup),
      AppRoutes.brigadeMissions,
    );
    expect(redirectForProfile(state, AppRoutes.brigadeDelivery), isNull);
    expect(
      redirectForProfile(state, AppRoutes.citizenSos),
      AppRoutes.brigadeMissions,
    );
  });
}
