// Basic smoke test: verify the app boots without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('PatientApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const PatientApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    // SplashScreen schedules a 2.5s delayed navigation; let it fire so no
    // timer is left pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 2600));
  });
}
