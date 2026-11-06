import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_harness.dart';
import 'helpers/test_app.dart';

/// Report 6.1.2: 48 x 48 touch targets, readable labels and contrast for
/// field use under stress, with gloves or in direct sunlight.
Future<void> expectAccessible(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

Future<void> registerCitizen(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('registration.fullName')),
    'María Quispe',
  );
  await tester.enterText(
    find.byKey(const Key('registration.phone')),
    '987654321',
  );
  await tester.ensureVisible(find.text('Continuar'));
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

Future<void> signInAsBrigadist(WidgetTester tester) async {
  final link = find.text('¿Ya tienes cuenta institucional? Inicia sesión');
  await tester.ensureVisible(link);
  await tester.tap(link);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('signIn.email')),
    'm.quispe@coerlima.gob.pe',
  );
  await tester.enterText(find.byKey(const Key('signIn.password')), 'secret');
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
}

void main() {
  late AppHarness app;

  setUp(() async => app = await AppHarness.create());

  group('citizen screens meet the accessibility guidelines', () {
    testWidgets('A_01 registration', (tester) async {
      await app.pump(tester);
      await expectAccessible(tester);
    });

    testWidgets('A_03 SOS and A_04 detail', (tester) async {
      await app.pump(tester);
      await registerCitizen(tester);
      await expectAccessible(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('Pedir auxilio')));
      await tester.pumpAndSettle();
      expect(find.text('Detalle de emergencia'), findsOneWidget);
      await expectAccessible(tester);
    });

    testWidgets('A_05 my reports and A_06 settings', (tester) async {
      await app.pump(tester);
      await registerCitizen(tester);

      await tester.tap(find.text('Mis reportes').last);
      await tester.pumpAndSettle();
      await expectAccessible(tester);

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
    });
  });

  group('brigade screens meet the accessibility guidelines', () {
    testWidgets('A_10 sign-in', (tester) async {
      await app.pump(tester);
      final link = find.text('¿Ya tienes cuenta institucional? Inicia sesión');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      await expectAccessible(tester);
    });

    testWidgets('A_07 missions with a mission', (tester) async {
      app.missionGateway.mission = sampleMission();
      await app.pump(tester);
      await signInAsBrigadist(tester);
      expect(find.text('Sector Santa Rosa'), findsOneWidget);
      await expectAccessible(tester);
    });
  });

  testWidgets('on a 360 x 640 phone the SOS is visible without scrolling', (
    tester,
  ) async {
    await app.pump(tester, size: const Size(360, 640));
    await registerCitizen(tester);

    final button = tester.getRect(
      find.bySemanticsLabel(RegExp('Pedir auxilio')),
    );
    expect(button.bottom, lessThan(640 - 80), reason: 'above the bottom bar');
  });

  group('small phones with large text', () {
    const smallPhone = Size(320, 568);

    testWidgets('registration, SOS and detail do not overflow', (tester) async {
      await app.pump(tester, size: smallPhone, textScale: 1.3);
      expect(tester.takeException(), isNull);

      await registerCitizen(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Solicitar Auxilio Urgente'), findsOneWidget);

      // On the smallest phones with large text the SOS needs a short scroll.
      await tester.drag(
        find.text('Solicitar Auxilio Urgente'),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('Pedir auxilio')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports and settings do not overflow', (tester) async {
      await app.pump(tester, size: smallPhone, textScale: 1.3);
      await registerCitizen(tester);

      await tester.tap(find.text('Mis reportes').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('missions do not overflow', (tester) async {
      app.missionGateway.mission = sampleMission();
      await app.pump(tester, size: smallPhone, textScale: 1.3);
      await signInAsBrigadist(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Sector Santa Rosa'), findsOneWidget);
    });
  });
}
