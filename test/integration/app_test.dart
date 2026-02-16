// Example integration test.
//
// Integration tests run the full app and drive it from the host.
// Run with: flutter test integration_test/app_test.dart
// https://docs.flutter.dev/testing/integration-tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_archive/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App', () {
    testWidgets('launches and shows home', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
