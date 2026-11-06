import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../emergencymanagement/application/citizen_report_sync.dart';
import '../../emergencymanagement/application/quick_evidence.dart';
import '../../emergencymanagement/application/sos_service.dart';
import '../../emergencymanagement/interfaces/pages/emergency_detail/emergency_detail_cubit.dart';
import '../../emergencymanagement/interfaces/pages/emergency_detail/emergency_detail_screen.dart';
import '../../emergencymanagement/interfaces/pages/my_reports/my_reports_cubit.dart';
import '../../emergencymanagement/interfaces/pages/my_reports/my_reports_screen.dart';
import '../../emergencymanagement/interfaces/pages/sos/sos_cubit.dart';
import '../../emergencymanagement/interfaces/pages/sos/sos_screen.dart';
import '../../identityaccess/application/auth_service.dart';
import '../../identityaccess/application/profile_service.dart';
import '../../identityaccess/domain/model/user_role.dart';
import '../../identityaccess/infrastructure/device/id_card_camera.dart';
import '../../identityaccess/interfaces/pages/brigade_credential/brigade_credential_cubit.dart';
import '../../identityaccess/interfaces/pages/brigade_credential/brigade_credential_screen.dart';
import '../../identityaccess/interfaces/pages/registration/registration_cubit.dart';
import '../../identityaccess/interfaces/pages/registration/registration_screen.dart';
import '../../identityaccess/interfaces/pages/sign_in/sign_in_cubit.dart';
import '../../identityaccess/interfaces/pages/sign_in/sign_in_screen.dart';
import '../../identityaccess/interfaces/profile_cubit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../networkstorage/application/offline_maps_service.dart';
import '../../networkstorage/application/storage_stats.dart';
import '../../networkstorage/interfaces/pages/network_storage/network_storage_cubit.dart';
import '../../networkstorage/interfaces/pages/network_storage/network_storage_screen.dart';
import '../../resourcemanagement/application/mission_service.dart';
import '../../resourcemanagement/infrastructure/device/navigation_launcher.dart';
import '../../resourcemanagement/interfaces/pages/missions/missions_cubit.dart';
import '../../resourcemanagement/interfaces/pages/missions/missions_screen.dart';
import '../../shared/interfaces/pages/startup/startup_screen.dart';
import '../../shared/interfaces/widgets/role_navigation_shell.dart';
import '../../traceability/application/delivery_evidence.dart';
import '../../traceability/application/delivery_service.dart';
import '../../traceability/infrastructure/device/explorer_launcher.dart';
import '../../traceability/interfaces/pages/delivery/delivery_cubit.dart';
import '../../traceability/interfaces/pages/delivery/delivery_screen.dart';
import '../config/app_config.dart';
import '../di/service_locator.dart';
import '../location/location_service.dart';
import '../maps/offline_first_tile_provider.dart';
import '../maps/offline_tile_store.dart';
import '../sync/outbox_repository.dart';
import '../sync/sync_cubit.dart';
import 'delivery_tab.dart';
import 'map_regions.dart';

/// Paths of the app. Each screen of the report gets its own constant.
abstract final class AppRoutes {
  static const String startup = '/';
  static const String registration = '/registration';
  static const String brigadeCredential = '/registration/credential';
  static const String registrationSignIn = '/registration/sign-in';

  static const String citizen = '/citizen';
  static const String citizenSos = '/citizen/sos';
  static const String citizenReports = '/citizen/reports';
  static const String citizenSettings = '/citizen/settings';
  static const String citizenReportDetail = '/citizen/report/:reportId/detail';

  static String reportDetail(String reportId, String code) =>
      '/citizen/report/$reportId/detail?code=$code';

  static const String brigade = '/brigade';
  static const String brigadeMissions = '/brigade/missions';
  static const String brigadeDelivery = '/brigade/delivery';
  static const String brigadeSettings = '/brigade/settings';
  static const String brigadeSignIn = '/brigade/sign-in';

  static String deliveryFor(String missionId) =>
      '$brigadeDelivery?mission=$missionId';
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
            onSignIn: () => context.push(AppRoutes.registrationSignIn),
          ),
        ),
        routes: [
          GoRoute(
            path: 'sign-in',
            builder: (context, state) =>
                _signIn(context, profileCubit, onBack: () => context.pop()),
          ),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.citizenSos,
                builder: (context, state) => BlocProvider(
                  create: (_) =>
                      SosCubit(getIt<SosService>(), getIt<LocationService>())
                        ..start(),
                  child: SosScreen(
                    onSosSaved: (report) => context.push(
                      AppRoutes.reportDetail(report.id, report.code),
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.citizenReports,
                builder: (context, state) => BlocProvider(
                  create: (_) =>
                      MyReportsCubit(getIt<MyReportsService>())..start(),
                  child: const MyReportsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.citizenSettings,
                builder: (context, state) {
                  final myLocation = AppLocalizations.of(
                    context,
                  ).regionMyLocation;
                  return BlocProvider(
                    create: (_) => NetworkStorageCubit(
                      getIt<OfflineMapsService>(),
                      getIt<StorageStatsSource>(),
                      dataChanges: getIt<OutboxRepository>().changes,
                      loadRegions: () => offlineRegions(
                        location: getIt<LocationService>(),
                        myLocationName: myLocation,
                      ),
                    )..start(),
                    child: const NetworkStorageScreen(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.citizenReportDetail,
        builder: (context, state) => BlocProvider(
          create: (_) => EmergencyDetailCubit(
            getIt<SosService>(),
            getIt<QuickEvidence>(),
            reportId: state.pathParameters['reportId']!,
          ),
          child: EmergencyDetailScreen(
            reportCode: state.uri.queryParameters['code'] ?? '',
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.citizenSos),
            onSent: () => context.go(AppRoutes.citizenReports),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.brigadeSignIn,
        builder: (context, state) =>
            _signIn(context, profileCubit, onBack: () => context.pop()),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.brigadeMissions,
                builder: (context, state) => MissionsScreen(
                  onSignIn: () => context.push(AppRoutes.brigadeSignIn),
                  createCubit: (fullName) => MissionsCubit(
                    getIt<MissionService>(),
                    getIt<LocationService>(),
                    fullName: fullName,
                  ),
                  onVerifyDelivery: (mission) =>
                      context.go(AppRoutes.deliveryFor(mission.id)),
                  onNavigate: getIt<NavigationLauncher>().navigateTo,
                  tileUrlTemplate: getIt<AppConfig>().mapTileUrlTemplate,
                  tileProvider: getIt.isRegistered<OfflineTileStore>()
                      ? OfflineFirstTileProvider(getIt<OfflineTileStore>())
                      : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.brigadeDelivery,
                builder: (context, state) => DeliveryTab(
                  missionId: state.uri.queryParameters['mission'],
                  missions: getIt<MissionService>(),
                  builder: (order) => DeliveryScreen(
                    order: order,
                    createCubit: (order) => DeliveryCubit(
                      getIt<DeliveryService>(),
                      getIt<DeliveryEvidence>(),
                      getIt<LocationService>(),
                      order: order,
                      onRegistered: getIt<MissionService>().complete,
                    ),
                    onNextMission: () => context.go(AppRoutes.brigadeMissions),
                    onOpenTransaction:
                        getIt<ExplorerLauncher>().openTransaction,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.brigadeSettings,
                builder: (context, state) {
                  final myLocation = AppLocalizations.of(
                    context,
                  ).regionMyLocation;
                  return BlocProvider(
                    create: (_) => NetworkStorageCubit(
                      getIt<OfflineMapsService>(),
                      getIt<StorageStatsSource>(),
                      dataChanges: getIt<OutboxRepository>().changes,
                      loadRegions: () => offlineRegions(
                        location: getIt<LocationService>(),
                        myLocationName: myLocation,
                        missions: getIt<MissionService>(),
                      ),
                    )..start(),
                    child: const NetworkStorageScreen(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _signIn(
  BuildContext context,
  ProfileCubit profileCubit, {
  required VoidCallback onBack,
}) {
  final router = GoRouter.of(context);
  return BlocProvider(
    create: (_) => SignInCubit(
      getIt<AuthService>(),
      onSignedIn: (result) {
        profileCubit.signedIn(result);
        getIt<SyncCubit>().sessionRestored();
        router.go(AppRoutes.brigadeMissions);
      },
    ),
    child: SignInScreen(onBack: onBack),
  );
}

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
