// Basic smoke test: verify the light/dark themes build into a working app.
// (Not testing full PatientApp boot: SplashScreen now makes real network /
// secure-storage / Firebase calls via AuthService that aren't mocked here.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/theme/app_theme.dart';

void main() {
  testWidgets('AppTheme.light and AppTheme.dark render without crashing',
      (WidgetTester tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const Scaffold(body: Text('ok')),
      ));
      await tester.pump();

      expect(find.text('ok'), findsOneWidget);
    }
  });
}
