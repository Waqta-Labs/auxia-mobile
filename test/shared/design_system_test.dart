import 'package:auxia_mobile/core/theme/app_spacing.dart';
import 'package:auxia_mobile/core/theme/app_theme.dart';
import 'package:auxia_mobile/shared/interfaces/widgets/app_card.dart';
import 'package:auxia_mobile/shared/interfaces/widgets/auxia_mark.dart';
import 'package:auxia_mobile/shared/interfaces/widgets/section_label.dart';
import 'package:auxia_mobile/shared/interfaces/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('primary buttons meet the 48 px touch target', (tester) async {
    await tester.pumpWidget(
      _wrap(FilledButton(onPressed: () {}, child: const Text('Continuar'))),
    );

    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
  });

  testWidgets('section labels are uppercase headers', (tester) async {
    await tester.pumpWidget(_wrap(const SectionLabel('¿Cuál es tu rol?')));

    expect(find.text('¿CUÁL ES TU ROL?'), findsOneWidget);
  });

  testWidgets('status chip shows its label', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusChip(label: 'Guardado', tone: StatusTone.info)),
    );

    expect(find.text('Guardado'), findsOneWidget);
  });

  testWidgets('tappable cards report their taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(AppCard(onTap: () => taps++, child: const Text('Ciudadano'))),
    );

    await tester.tap(find.text('Ciudadano'));
    expect(taps, 1);
  });

  testWidgets('the isotype is announced as AuxIA', (tester) async {
    await tester.pumpWidget(_wrap(const AuxiaMark()));

    expect(find.bySemanticsLabel('AuxIA'), findsOneWidget);
  });
}
