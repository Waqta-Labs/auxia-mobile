import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../emergencymanagement/interfaces/pages/my_reports/my_reports_screen.dart';
import '../../emergencymanagement/interfaces/pages/sos/sos_screen.dart';
import '../../identityaccess/application/profile_service.dart';
import '../../identityaccess/domain/model/user_role.dart';
import '../../identityaccess/infrastructure/device/id_card_camera.dart';
import '../../identityaccess/interfaces/pages/brigade_credential/brigade_credential_cubit.dart';
import '../../identityaccess/interfaces/pages/brigade_credential/brigade_credential_screen.dart';
import '../../identityaccess/interfaces/pages/registration/registration_cubit.dart';
import '../../identityaccess/interfaces/pages/registration/registration_screen.dart';
import '../../identityaccess/interfaces/profile_cubit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../networkstorage/interfaces/pages/network_storage/network_storage_screen.dart';
import '../../resourcemanagement/interfaces/pages/missions/missions_screen.dart';
import '../../shared/interfaces/pages/startup/startup_screen.dart';
import '../../shared/interfaces/widgets/role_navigation_shell.dart';
import '../../traceability/interfaces/pages/delivery/delivery_screen.dart';
import '../di/service_locator.dart';

/// Paths of the app. Each screen of the report gets its own constant.
abstract final class AppRoutes {
  static const String startup = '/';
  static const String registration = '/registration';
  static const String brigadeCredential = '/registration/credential';

  static const String citizen = '/citizen';
  static const String citizenSos = '/citizen/sos';
  static const String citizenReports = '/citizen/reports';
  static const String citizenSettings = '/citizen/settings';

  static const String brigade = '/brigade';
  static const String brigadeMissions = '/brigade/missions';
  static const String brigadeDelivery = '/brigade/delivery';
  static const String brigadeSettings = '/brigade/settings';
}

/// Sends each user to the place that matches the local profile: the
/// registration while there is none, and the bottom navigation of the role
/// once it exists.
String? redirectForProfile(ProfileState profile, String location) {
  switch (profile.status) {
    case ProfileStatus.loading:
      return location == AppRoutes.startup ? null : AppRoutes.startup;
    case ProfileStatus.absent:
      return location.startsWith(AppRoutes.registration)
          ? null
          : AppRoutes.registration;
    case ProfileStatus.present:
      final home = profile.role == UserRole.brigadist
          ? AppRoutes.brigade
          : AppRoutes.citizen;
      if (location.startsWith(home)) return null;
      return profile.role == UserRole.brigadist
          ? AppRoutes.brigadeMissions
          : AppRoutes.citizenSos;
  }
}

GoRouter createAppRouter({required ProfileCubit profileCubit}) {
  return GoRouter(
    initialLocation: AppRoutes.startup,
    refreshListenable: _CubitListenable(profileCubit),
    redirect: (context, state) =>
        redirectForProfile(profileCubit.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.registration,
        builder: (context, state) => BlocProvider(
          create: (_) => RegistrationCubit(
            getIt<ProfileService>(),
            onRegistered: profileCubit.registered,
          ),
          child: RegistrationScreen(
            onContinueToCredential: (pending) =>
                context.push(AppRoutes.brigadeCredential, extra: pending),
          ),
        ),
        routes: [
          GoRoute(
            path: 'credential',
            redirect: (context, state) => state.extra is PendingRegistration
                ? null
                : AppRoutes.registration,
            builder: (context, state) => BlocProvider(
              create: (_) => BrigadeCredentialCubit(
                getIt<ProfileService>(),
                pending: state.extra! as PendingRegistration,
                captureIdCard: getIt<IdCardCamera>().capture,
                onRegistered: profileCubit.registered,
              ),
              child: BrigadeCredentialScreen(onBack: () => context.pop()),
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          final l10n = AppLocalizations.of(context);
          return RoleNavigationShell(
            shell: shell,
            destinations: [
              RoleDestination(
                label: l10n.navSos,
                icon: Icons.sos_outlined,
                selectedIcon: Icons.sos,
              ),
              RoleDestination(
                label: l10n.navMyReports,
                icon: Icons.list_alt_outlined,
                selectedIcon: Icons.list_alt,
              ),
              RoleDestination(
                label: l10n.navSettings,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
              ),
            ],
          );
        },
        branches: [
          _branch(AppRoutes.citizenSos, const SosScreen()),
          _branch(AppRoutes.citizenReports, const MyReportsScreen()),
          _branch(AppRoutes.citizenSettings, const NetworkStorageScreen()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          final l10n = AppLocalizations.of(context);
          return RoleNavigationShell(
            shell: shell,
            destinations: [
              RoleDestination(
                label: l10n.navMissions,
                icon: Icons.map_outlined,
                selectedIcon: Icons.map,
              ),
              RoleDestination(
                label: l10n.navDelivery,
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2,
              ),
              RoleDestination(
                label: l10n.navSettings,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
              ),
            ],
          );
        },
        branches: [
          _branch(AppRoutes.brigadeMissions, const MissionsScreen()),
          _branch(AppRoutes.brigadeDelivery, const DeliveryScreen()),
          _branch(AppRoutes.brigadeSettings, const NetworkStorageScreen()),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

/// Lets go_router re-run its redirect when the profile changes.
class _CubitListenable extends ChangeNotifier {
  _CubitListenable(Cubit<Object?> cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
