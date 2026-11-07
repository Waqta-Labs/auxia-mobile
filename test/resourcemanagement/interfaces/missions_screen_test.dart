import 'package:auxia_mobile/core/sync/sync_cubit.dart';
import 'package:auxia_mobile/identityaccess/application/auth_service.dart';
import 'package:auxia_mobile/identityaccess/application/profile_service.dart';
import 'package:auxia_mobile/identityaccess/domain/model/brigade_credential.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/user_role.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:auxia_mobile/identityaccess/interfaces/profile_cubit.dart';
import 'package:auxia_mobile/l10n/generated/app_localizations_es.dart';
import 'package:auxia_mobile/resourcemanagement/application/mission_service.dart';
import 'package:auxia_mobile/resourcemanagement/domain/model/mission.dart';
import 'package:auxia_mobile/resourcemanagement/infrastructure/persistence/sqlite_mission_cache.dart';
import 'package:auxia_mobile/resourcemanagement/interfaces/pages/missions/missions_cubit.dart';
import 'package:auxia_mobile/resourcemanagement/interfaces/pages/missions/missions_screen.dart';
import 'package:auxia_mobile/resourcemanagement/interfaces/widgets/mission_card.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  final l10n = AppLocalizationsEs();

  test('the priority is explained in plain words, biggest first', () {
    final mission = sampleMission();

    expect(
      priorityExplanation(l10n, mission),
      'Daño severo, 3 niños, 1 adulto mayor, 2 con discapacidad',
    );
  });

  test('a mission without explanation names the Command Center', () {
    const mission = Mission(
      id: 'd',
      brigadeId: 'b',
      brigadeName: 'B',
      planId: 'p',
      zoneId: 'z',
      zoneName: 'Z',
      priority: PriorityLevel.high,
      status: MissionStatus.assigned,
    );

    expect(
      priorityExplanation(l10n, mission),
      'Prioridad asignada por el Centro de Mando.',
    );
  });

  group('MissionsScreen (A_07)', () {
    late Database db;
    late FakeMissionGateway gateway;
    late InMemorySessionRepository sessions;
    late ProfileCubit profileCubit;
    late MissionService service;
    final navigatedTo = <GeoPoint>[];
    final verified = <Mission>[];

    setUp(() async {
      db = await openTestDatabase();
      gateway = FakeMissionGateway(mission: sampleMission());
      sessions = InMemorySessionRepository()..session = brigadeSession();
      final profiles = InMemoryProfileRepository();
      final auth = AuthService(FakeAuthenticationGateway(), sessions, profiles);
      final signedIn = await auth.signIn(
        email: InstitutionalEmail('m.quispe@coerlima.gob.pe'),
        password: Password('secret-123'),
      );
      profileCubit = ProfileCubit(ProfileService(profiles), auth)
        ..signedIn(signedIn.getRight().toNullable()!);
      navigatedTo.clear();
      verified.clear();
    });

    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 5000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      service = MissionService(gateway, SqliteMissionCache(db));
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: profileCubit),
            BlocProvider(create: (_) => SyncCubit(FakeSyncController())),
          ],
          child: localizedApp(
            MissionsScreen(
              onSignIn: () {},
              createCubit: () => MissionsCubit(service, FakeLocationService()),
              onVerifyDelivery: verified.add,
              onNavigate: (point) async {
                navigatedTo.add(point);
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the mission of the brigade with its explanation', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Brigada Alfa'), findsOneWidget);
      expect(find.text('Sector Santa Rosa'), findsOneWidget);
      expect(find.text('Médico'), findsOneWidget);
      expect(find.textContaining('Médico · hace'), findsOneWidget);
      expect(find.text('POR QUÉ ESTA PRIORIDAD'), findsOneWidget);
      expect(find.text('Prioridad crítica'), findsOneWidget);
      expect(find.text('12 kits · Kit de víveres'), findsOneWidget);
      expect(find.text('GPS -12.0432, -77.0428'), findsOneWidget);
      expect(find.text('0.4 km · 1 min'), findsOneWidget);
      expect(find.text('1 misión · Urgency Score IA'), findsOneWidget);
    });

    testWidgets('starting navigation opens the maps app and verifying '
        'opens the delivery', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Iniciar navegación'));
      await tester.pumpAndSettle();

      expect(navigatedTo.single, const GeoPoint(-12.0432, -77.0428));
      expect(find.text('Navegación en curso'), findsOneWidget);

      await tester.tap(find.text('Verificar entrega'));
      expect(verified.single.deliveryId, 'delivery-1');
    });

    testWidgets('a delivery registered on A_08 shows the mission completed', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Iniciar navegación'));
      await tester.pumpAndSettle();

      // A_08 lives in another tab: this screen stays alive meanwhile.
      await tester.runAsync(() => service.complete('delivery-1'));
      await tester.pumpAndSettle();

      expect(find.text('Misión completada'), findsOneWidget);
      expect(find.text('Verificar entrega'), findsNothing);
    });

    testWidgets('a delivery not opened yet cannot be verified', (tester) async {
      gateway.mission = sampleMission(deliveryId: null);
      await pump(tester);

      await tester.tap(find.text('Iniciar navegación'));
      await tester.pumpAndSettle();

      expect(find.text('Verificar entrega'), findsNothing);
      expect(find.textContaining('Centro de Mando la abra'), findsOneWidget);
    });

    testWidgets('without GPS it shows the distance from the base', (
      tester,
    ) async {
      gateway.mission = const Mission(
        id: 'plan-2',
        brigadeId: 'b',
        brigadeName: 'Brigada Alfa',
        planId: 'plan-2',
        zoneId: 'z',
        zoneName: 'Zona sin GPS',
        priority: PriorityLevel.high,
        status: MissionStatus.assigned,
        baseDistanceKm: 3.2,
        baseEtaMinutes: 7,
      );
      await pump(tester);

      expect(find.text('3.2 km · 7 min'), findsOneWidget);
    });

    testWidgets('an account in no brigade is told to ask for it', (
      tester,
    ) async {
      gateway
        ..brigadeName = null
        ..mission = null;
      await pump(tester);

      expect(find.text('Tu cuenta aún no está en una brigada'), findsOneWidget);
      expect(find.text('Elige tu brigada'), findsNothing);
    });

    LocalProfile credentialProfile(CredentialStatus status, {String? reason}) =>
        LocalProfile.register(
          fullName: FullName('Miguel Quispe'),
          phone: PhoneNumber('987654321'),
          role: UserRole.brigadist,
          now: DateTime(2026, 11, 7),
        ).withCredential(
          BrigadeCredential.create(
            organization: OrganizationName('Defensa Civil'),
            brigadeCode: BrigadeCode('BRG-ALFA-07'),
            now: DateTime(2026, 11, 7),
          ).withStatus(status, reason: reason),
        );

    testWidgets('a pending credential can be checked again', (tester) async {
      profileCubit.registered(
        credentialProfile(CredentialStatus.pendingApproval),
      );
      await pump(tester);

      expect(
        find.text('Tu cuenta está pendiente de aprobación'),
        findsOneWidget,
      );
      expect(find.textContaining('sin escribir contraseña'), findsOneWidget);
      expect(find.text('Consultar estado'), findsOneWidget);
    });

    testWidgets('a rejected credential shows the reason', (tester) async {
      profileCubit.registered(
        credentialProfile(CredentialStatus.rejected, reason: 'Carnet ilegible'),
      );
      await pump(tester);

      expect(find.text('Tu credencial fue rechazada'), findsOneWidget);
      expect(find.text('Carnet ilegible'), findsOneWidget);
      expect(find.text('Consultar estado'), findsNothing);
    });
  });
}
