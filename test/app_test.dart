import 'package:auxia_mobile/app.dart';
import 'package:auxia_mobile/core/localization/locale_cubit.dart';
import 'package:auxia_mobile/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the brand in spanish by default', (tester) async {
    await tester.pumpWidget(
      AuxiaApp(router: createAppRouter(), localeCubit: LocaleCubit()),
    );
    await tester.pumpAndSettle();

    expect(find.text('AuxIA'), findsOneWidget);
    expect(find.text('Auxilio y coordinación offline'), findsOneWidget);
  });

  testWidgets('switches the interface to english', (tester) async {
    final localeCubit = LocaleCubit();
    await tester.pumpWidget(
      AuxiaApp(router: createAppRouter(), localeCubit: localeCubit),
    );
    await tester.pumpAndSettle();

    localeCubit.change(const Locale('en'));
    await tester.pumpAndSettle();

    expect(find.text('Offline aid and coordination'), findsOneWidget);
  });

  test('falls back to spanish for unsupported languages', () {
    final localeCubit = LocaleCubit()..change(const Locale('fr'));

    expect(localeCubit.state, const Locale('es'));
    expect(localeCubit.languageTag, 'es');
  });
}
