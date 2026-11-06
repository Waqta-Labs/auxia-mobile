import 'package:auxia_mobile/app.dart';
import 'package:auxia_mobile/core/di/service_locator.dart';
import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/core/localization/locale_cubit.dart';
import 'package:auxia_mobile/core/location/location_service.dart';
import 'package:auxia_mobile/core/routing/app_router.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/core/sync/sync_cubit.dart';
import 'package:auxia_mobile/emergencymanagement/application/quick_evidence.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/identityaccess/application/auth_service.dart';
import 'package:auxia_mobile/identityaccess/application/profile_service.dart';
import 'package:auxia_mobile/identityaccess/infrastructure/device/id_card_camera.dart';
import 'package:auxia_mobile/identityaccess/interfaces/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/test_app.dart';

class _FakeCamera extends Mock implements IdCardCamera {}

void main() {
  late InMemoryProfileRepository repository;
  late LocaleCubit localeCubit;
  late ProfileCubit profileCubit;
  late FakeAuthenticationGateway gateway;
  late InMemorySessionRepository sessions;

  setUp(() async {
    await getIt.reset();
    final db = await openTestDatabase();
    getIt.registerSingleton<SosService>(
      SosService(SqliteCitizenReportRepository(db), OutboxRepository(db)),
    );
    repository = InMemoryProfileRepository();
    final service = ProfileService(repository);
    gateway = FakeAuthenticationGateway();
    sessions = InMemorySessionRepository();
    final auth = AuthService(gateway, sessions, repository);
    localeCubit = LocaleCubit();
    profileCubit = ProfileCubit(service, auth);
    getIt
      ..registerSingleton<ProfileService>(service)
      ..registerSingleton<AuthService>(auth)
      ..registerSingleton<SyncCubit>(SyncCubit(FakeSyncController()))
      ..registerSingleton<LocationService>(FakeLocationService())
      ..registerSingleton<QuickEvidence>(FakeQuickEvidence())
      ..registerSingleton<IdCardCamera>(_FakeCamera());
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      AuxiaApp(
        router: createAppRouter(profileCubit: profileCubit),
        localeCubit: localeCubit,
        profileCubit: profileCubit,
        syncCubit: SyncCubit(FakeSyncController()),
      ),
    );
    await profileCubit.load();
    await tester.pumpAndSettle();
  }

  testWidgets('a new user starts on the registration in spanish', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Tus datos se guardan en tu dispositivo'), findsOneWidget);
  });

  testWidgets('a citizen registers and gets the citizen navigation', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('registration.fullName')),
      'María Quispe',
    );
    await tester.enterText(
      find.byKey(const Key('registration.phone')),
      '+51 987 654 321',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Solicitar Auxilio Urgente'), findsOneWidget);
    expect(find.text('Mis reportes'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('a citizen sends an SOS with detail and sees Mis reportes', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('registration.fullName')),
      'María Quispe',
    );
    await tester.enterText(
      find.byKey(const Key('registration.phone')),
      '987654321',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('GPS -12.0464, -77.0428 · guardado'),
      200,
    );
    await tester.tap(find.text('Rescate'));
    await tester.pump();
    await tester.tap(
      find.bySemanticsLabel('Pedir auxilio: enviar SOS de Rescate'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalle de emergencia'), findsOneWidget);
    await tester.tap(find.byTooltip('Agregar uno a Niños'));
    await tester.tap(find.text('Vía bloqueada'));
    await tester.pump();
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.text('Guardar y Enviar Auxilio'));
    await tester.pumpAndSettle();

    expect(find.text('Mis reportes'), findsWidgets);
  });

  testWidgets('a brigadist sends the credential and lands on missions', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('registration.fullName')),
      'Cap. M. Quispe',
    );
    await tester.enterText(
      find.byKey(const Key('registration.phone')),
      '987654321',
    );
    await tester.ensureVisible(find.text('Brigadista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brigadista'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Credencial de brigadista'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('credential.organization')),
      'Defensa Civil · Región Lima',
    );
    await tester.enterText(
      find.byKey(const Key('credential.brigadeCode')),
      'BRG-ALFA-07',
    );
    await tester.ensureVisible(find.text('Enviar para aprobación'));
    await tester.tap(find.text('Enviar para aprobación'));
    await tester.pumpAndSettle();

    expect(find.text('Tu cuenta está pendiente de aprobación'), findsOneWidget);
    expect(find.text('Misiones'), findsOneWidget);
    expect(find.text('Entrega'), findsOneWidget);
  });

  testWidgets('changing the role goes back to the registration', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('registration.fullName')),
      'María Quispe',
    );
    await tester.enterText(
      find.byKey(const Key('registration.phone')),
      '987654321',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('María Quispe'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cambiar de rol'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cambiar de rol'));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(repository.profile, isNull);
  });

  testWidgets('a brigadist with an account signs in from the registration', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.ensureVisible(
      find.text('¿Ya tienes cuenta institucional? Inicia sesión'),
    );
    await tester.tap(
      find.text('¿Ya tienes cuenta institucional? Inicia sesión'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Correo institucional'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('signIn.email')),
      'm.quispe@coerlima.gob.pe',
    );
    await tester.enterText(find.byKey(const Key('signIn.password')), 'secret');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No tienes misiones asignadas'), findsOneWidget);
    expect(sessions.session, isNotNull);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Cap. M. Quispe'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(sessions.session, isNull);
    expect(find.widgetWithText(OutlinedButton, 'Cerrar sesión'), findsNothing);
  });

  testWidgets('the sign-in shows the generic error of the backend', (
    tester,
  ) async {
    gateway.result = const Left(
      UnauthorizedFailure('Credenciales no válidas.'),
    );
    await pumpApp(tester);
    await tester.ensureVisible(
      find.text('¿Ya tienes cuenta institucional? Inicia sesión'),
    );
    await tester.tap(
      find.text('¿Ya tienes cuenta institucional? Inicia sesión'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('signIn.email')),
      'm.quispe@coerlima.gob.pe',
    );
    await tester.enterText(find.byKey(const Key('signIn.password')), 'wrong');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Credenciales no válidas.'), findsOneWidget);
  });

  testWidgets('the interface switches to english', (tester) async {
    await pumpApp(tester);

    localeCubit.change(const Locale('en'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
  });
}
