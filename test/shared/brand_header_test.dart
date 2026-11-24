import 'package:auxia_mobile/shared/interfaces/widgets/brand_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('the role badge sits on the right edge', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(
          body: SizedBox(
            width: 400,
            child: BrandHeader(trailing: Text('Ciudadano')),
          ),
        ),
      ),
    );

    final header = tester.getRect(find.byType(BrandHeader));
    final badge = tester.getRect(find.text('Ciudadano'));
    expect(badge.right, header.right);
  });
}
