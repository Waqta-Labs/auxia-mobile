import 'package:auxia_mobile/core/sync/sync_cubit.dart';
import 'package:auxia_mobile/identityaccess/application/auth_service.dart';
import 'package:auxia_mobile/identityaccess/application/profile_service.dart';
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
      final service = MissionService(gateway, SqliteMissionCache(db));
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: profileCubit),
            BlocProvider(create: (_) => SyncCubit(FakeSyncController())),
          ],
          child: localizedApp(
            MissionsScreen(
              onSignIn: () {},
              createCubit: (name) =>
                  MissionsCubit(service, FakeLocationService(), fullName: name),
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
      expect(verified.single.id, 'delivery-1');
    });

    testWidgets('a brigadist without brigade chooses one', (tester) async {
      gateway.brigadeList = const [
        BrigadeSummary(id: 'b1', name: 'Brigada Uno', memberNames: []),
        BrigadeSummary(id: 'b2', name: 'Brigada Dos', memberNames: []),
      ];
      gateway.mission = null;
      await pump(tester);

      expect(find.text('Elige tu brigada'), findsOneWidget);
      await tester.tap(find.text('Brigada Dos'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No tienes misiones asignadas'),
        findsOneWidget,
      );
    });
  });
}
