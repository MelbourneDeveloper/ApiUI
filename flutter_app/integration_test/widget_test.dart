// fine for tests
// ignore_for_file: do_not_use_environment

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import '../test/widget_test.dart' as wt;
import '../test/widget_test_helpers.dart';

/// Integration assertions - just verify UI is in valid state
void _integrationSessionAssertion(WidgetTester tester) {
  expect(find.byType(ListView), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);
}

void _integrationResponseAssertion(WidgetTester tester, String sentMsg) {
  // Just verify loading is gone and list is visible
  // Don't check message text - real LLM responses won't match mock expectations
  expect(find.byType(ListView), findsOneWidget);
  expect(find.byType(LinearProgressIndicator), findsNothing);
  // Ignore sentMsg - it's just for API compatibility with mock tests
}

TestConfig _createIntegrationConfig() => (
  client: http.Client(),
  baseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  ),
  assertSessionCreated: _integrationSessionAssertion,
  assertResponseReceived: _integrationResponseAssertion,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test Multi Turn Conversation', (tester) async {
    await wt.testMultiTurnConversation(
      tester,
      config: _createIntegrationConfig(),
    );
  });

  testWidgets('Test Dirty State', (tester) async {
    await wt.testDirtyState(tester, config: _createIntegrationConfig());
  });

  testWidgets('Test Input Bar Structure', (tester) async {
    await wt.inputBarHasCorrectStructure(
      tester,
      config: _createIntegrationConfig(),
    );
  });

  testWidgets('Test Chart Rendering', (tester) async {
    await wt.testChartRendering(tester, config: _createIntegrationConfig());
  });
}
