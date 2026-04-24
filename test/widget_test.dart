import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:badmintonshop/presentation/widgets/app_shell.dart';

void main() {
  testWidgets('App shell renders bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          selectedIndex: 0,
          onTabChanged: (_) {},
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('SHOP'), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
  });
}
