import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/src/chat_api.dart' show defaultBaseUrl;
import 'package:flutter_app/src/logging/logging.dart';
import 'package:flutter_app/src/oauth_handler.dart';
import 'package:flutter_app/src/services/file_saver_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nimble_charts/flutter.dart' as charts;

import 'widget_test_helpers.dart';

const _screenSizes = [
  ('phone', Size(390, 844)),
  ('tablet', Size(768, 1024)),
  ('desktop', Size(1920, 1080)),
];

void main() {
  for (final (sizeName, size) in _screenSizes) {
    group(sizeName, () {
      Future<void> runAtSize(
        WidgetTester tester,
        Future<void> Function(WidgetTester) test,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        await test(tester);
      }

      testWidgets('multi-turn conversation', (tester) async {
        await runAtSize(tester, testMultiTurnConversation);
      });

      testWidgets('error recovery', (tester) async {
        await runAtSize(tester, _testErrorRecovery);
      });

      testWidgets('OAuth flow', (tester) async {
        await runAtSize(tester, _testOAuthFlow);
      });

      testWidgets('dirty state', (tester) async {
        await runAtSize(tester, testDirtyState);
      });

      testWidgets('input bar structure', (tester) async {
        await runAtSize(tester, inputBarHasCorrectStructure);
      });

      testWidgets('chart rendering', (tester) async {
        await runAtSize(tester, testChartRendering);
      });

      testWidgets('image content', (tester) async {
        await runAtSize(tester, _testImageContent);
      });

      testWidgets('link content', (tester) async {
        await runAtSize(tester, _testLinkContent);
      });

      testWidgets('file content', (tester) async {
        await runAtSize(tester, _testFileContent);
      });

      testWidgets('OAuth dialog cancel', (tester) async {
        await runAtSize(tester, _testOAuthDialogCancel);
      });

      testWidgets('OAuth dialog sign in', (tester) async {
        await runAtSize(tester, _testOAuthDialogSignIn);
      });

      testWidgets('golden empty state', (tester) async {
        await runAtSize(tester, (t) => _goldenEmptyState(t, sizeName));
      });

      testWidgets('golden with messages', (tester) async {
        await runAtSize(tester, (t) => _goldenWithMessages(t, sizeName));
      });

      testWidgets('golden with chart', (tester) async {
        await runAtSize(tester, (t) => _goldenWithChart(t, sizeName));
      });

      testWidgets('golden with auth card', (tester) async {
        await runAtSize(tester, (t) => _goldenWithAuthCard(t, sizeName));
      });

      testWidgets('golden with image', (tester) async {
        await runAtSize(tester, (t) => _goldenWithImage(t, sizeName));
      });

      testWidgets('golden with file', (tester) async {
        await runAtSize(tester, (t) => _goldenWithFile(t, sizeName));
      });
    });
  }
}

Future<void> _testErrorRecovery(WidgetTester tester) async {
  var sessionAttempts = 0;
  var firstMessageAttempts = 0;
  final successfulMessages = <String>[];

  final client = createMockClient(
    onCreateSession: () {
      sessionAttempts++;
      return sessionAttempts >= 3
          ? successSessionResponse(id: 'retry-session')
          : errorSessionResponse(statusCode: 503);
    },
    onSendMessage: (msg) {
      final isFirstMessage = msg.contains('first');
      if (isFirstMessage) firstMessageAttempts++;

      return switch ((isFirstMessage, firstMessageAttempts)) {
        (true, final attempts) when attempts <= 2 => errorChatResponse(),
        (true, _) => () {
          successfulMessages.add(msg);
          return successChatResponse(response: 'Retry worked!');
        }(),
        (false, _) => () {
          successfulMessages.add(msg);
          return successChatResponse(response: 'Second message OK');
        }(),
      };
    },
  );

  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  await tester.pumpAndSettle();

  expect(sessionAttempts, greaterThanOrEqualTo(3));
  expect(find.byType(CircularProgressIndicator), findsNothing);

  await tester.enterText(find.byType(TextField), 'first message');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pump();
  expect(find.byType(AnimatedBuilder), findsWidgets);
  await tester.pumpAndSettle();

  expect(find.text('Retry worked!'), findsOneWidget);
  expect(firstMessageAttempts, greaterThan(2));

  await tester.enterText(find.byType(TextField), 'second message');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  expect(find.text('Second message OK'), findsOneWidget);
  expect(successfulMessages.length, 2);
}

Future<void> _testOAuthFlow(WidgetTester tester) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (msg) => switch (msg.toLowerCase()) {
      final m when m.contains('calendar') => chatResponseWithAuthRequired(
        response: 'Need to access your calendar. Please sign in:',
        authUrl: 'https://accounts.google.com/oauth',
      ),
      _ => successChatResponse(response: 'Calendar events retrieved!'),
    },
  );

  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'show my calendar');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  expect(find.textContaining('Need to access your calendar'), findsOneWidget);
  expect(find.textContaining('google'), findsWidgets);
  expect(find.byIcon(Icons.lock), findsWidgets);
  expect(find.text('Sign In'), findsWidgets);
}

Future<void> _testImageContent(WidgetTester tester) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) => chatResponseWithImage(
      response: 'Here is an image for you:',
      imageUrl: 'https://example.com/test.png',
    ),
  );

  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'show image');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  expect(find.textContaining('Here is an image'), findsOneWidget);
  expect(find.byType(Image), findsOneWidget);
}

Future<void> _testLinkContent(WidgetTester tester) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) => chatResponseWithLink(
      response: 'Check out this link:',
      title: 'Example Site',
    ),
  );

  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'show link');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  expect(find.textContaining('Check out this link'), findsOneWidget);
  expect(find.byIcon(Icons.link), findsOneWidget);
  expect(find.text('Example Site'), findsOneWidget);
}

Future<void> _testFileContent(WidgetTester tester) async {
  final savedFiles = <({String name, String content})>[];
  final originalSaver = fileSaver;
  fileSaver = ({required name, required content}) async {
    savedFiles.add((name: name, content: content));
  };
  addTearDown(() => fileSaver = originalSaver);

  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) => chatResponseWithFile(
      response: 'Here is the file:',
      name: 'document.txt',
      content: 'Hello, World!',
    ),
  );

  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'show file');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  expect(find.textContaining('Here is the file'), findsOneWidget);
  expect(find.byIcon(Icons.download), findsOneWidget);
  expect(find.text('document.txt'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.download));
  await tester.pumpAndSettle();

  expect(savedFiles.length, 1);
  expect(savedFiles.first.name, 'document.txt');
  expect(savedFiles.first.content, 'Hello, World!');
}

Future<void> _testOAuthDialogCancel(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => handleOAuthRequired(
              context: context,
              provider: 'GitHub',
              authUrl: 'https://github.com/login/oauth',
            ),
            child: const Text('Trigger OAuth'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Trigger OAuth'));
  await tester.pumpAndSettle();

  expect(find.text('Authentication Required'), findsOneWidget);
  expect(find.text('Sign in with GitHub to continue.'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.text('Sign In'), findsOneWidget);

  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();

  expect(find.text('Authentication Required'), findsNothing);
}

Future<void> _testOAuthDialogSignIn(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => handleOAuthRequired(
              context: context,
              provider: 'Google',
              authUrl: 'https://accounts.google.com/oauth',
            ),
            child: const Text('Trigger OAuth'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Trigger OAuth'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Sign In'));
  await tester.pumpAndSettle();

  expect(find.text('Authentication Required'), findsNothing);
}

Future<void> testDirtyState(WidgetTester tester, {TestConfig? config}) async {
  final sentMessages = <String>[];
  var messageCounter = 0;

  final testConfig =
      config ??
      (
        client: createMockClient(
          onCreateSession: successSessionResponse,
          onSendMessage: (msg) {
            sentMessages.add(msg);
            messageCounter++;
            return successChatResponse(response: 'Response #$messageCounter');
          },
        ),
        baseUrl: defaultBaseUrl,
        assertSessionCreated: mockSessionAssertion,
        assertResponseReceived: createMockResponseAssertion(
          expectedResponses: {},
        ),
      );

  await tester.pumpWidget(
    _TestApp(
      logging: createLoggingContext(),
      client: testConfig.client,
      baseUrl: testConfig.baseUrl,
    ),
  );
  await tester.pumpAndSettle();
  testConfig.assertSessionCreated(tester);

  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pump();
  if (config == null) expect(sentMessages, isEmpty);

  const specialMsg = 'Special: {"emoji": "🔥"}';
  await tester.enterText(find.byType(TextField), specialMsg);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
  testConfig.assertResponseReceived(tester, specialMsg);

  if (config == null) {
    expect(sentMessages, contains(specialMsg));
    expect(find.textContaining('Response #1'), findsOneWidget);
  }

  for (final i in [1, 2, 3]) {
    await tester.enterText(find.byType(TextField), 'Message $i');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    testConfig.assertResponseReceived(tester, 'Message $i');
  }

  if (config == null) {
    expect(sentMessages.length, 4);
    expect(sentMessages, contains('Message 1'));
    expect(sentMessages, contains('Message 2'));
    expect(sentMessages, contains('Message 3'));
  }
}

Future<void> testMultiTurnConversation(
  WidgetTester tester, {
  TestConfig? config,
}) async {
  final sentMessages = <String>[];
  var sessionCreated = false;

  final testConfig =
      config ??
      (
        client: createMockClient(
          onCreateSession: () {
            sessionCreated = true;
            return successSessionResponse(id: 'conversation-session-001');
          },
          onSendMessage: (msg) {
            sentMessages.add(msg);
            return switch (msg.toLowerCase()) {
              final m when m.contains('japan') => successChatResponse(
                response: 'Japan is an island nation with capital Tokyo.',
              ),
              final m when m.contains('france') => successChatResponse(
                response: 'France is a country in Europe. Capital: Paris.',
              ),
              final m when m.contains('europe') => successChatResponse(
                response: 'Countries in Europe: Germany, France, Italy.',
              ),
              final m when m.contains('australia') => successChatResponse(
                response: 'Australia has population of 25 million.',
              ),
              _ => successChatResponse(response: 'Got it: $msg'),
            };
          },
        ),
        baseUrl: defaultBaseUrl,
        assertSessionCreated: mockSessionAssertion,
        assertResponseReceived: createMockResponseAssertion(
          expectedResponses: {},
        ),
      );

  await tester.pumpWidget(
    _TestApp(
      logging: createLoggingContext(),
      client: testConfig.client,
      baseUrl: testConfig.baseUrl,
    ),
  );
  await tester.pumpAndSettle();
  testConfig.assertSessionCreated(tester);

  if (config == null) expect(sessionCreated, isTrue);

  await tester.enterText(find.byType(TextField), 'Tell me about Japan');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  if (config == null) {
    expect(sentMessages, contains('Tell me about Japan'));
    expect(find.textContaining('Tokyo'), findsOneWidget);
  }
  testConfig.assertResponseReceived(tester, 'Tell me about Japan');

  await tester.enterText(
    find.byType(TextField),
    'What is the capital of France?',
  );
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  if (config == null) {
    expect(sentMessages, contains('What is the capital of France?'));
    expect(find.textContaining('Paris'), findsOneWidget);
  }
  testConfig.assertResponseReceived(tester, 'What is the capital of France?');

  await tester.enterText(find.byType(TextField), 'List 3 countries in Europe');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  if (config == null) {
    expect(sentMessages, contains('List 3 countries in Europe'));
    expect(find.textContaining('Germany'), findsOneWidget);
  }
  testConfig.assertResponseReceived(tester, 'List 3 countries in Europe');

  await tester.enterText(
    find.byType(TextField),
    'What is the population of Australia?',
  );
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  if (config == null) {
    expect(sentMessages, contains('What is the population of Australia?'));
    expect(find.textContaining('Australia'), findsNWidgets(2));
    expect(sentMessages.length, 4);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
  }
  testConfig.assertResponseReceived(
    tester,
    'What is the population of Australia?',
  );
}

Future<void> inputBarHasCorrectStructure(
  WidgetTester tester, {
  TestConfig? config,
}) async {
  final testConfig =
      config ??
      (
        client: createMockClient(
          onCreateSession: successSessionResponse,
          onSendMessage: (_) => successChatResponse(),
        ),
        baseUrl: defaultBaseUrl,
        assertSessionCreated: mockSessionAssertion,
        assertResponseReceived: createMockResponseAssertion(
          expectedResponses: {},
        ),
      );

  await tester.pumpWidget(
    _TestApp(
      logging: createLoggingContext(),
      client: testConfig.client,
      baseUrl: testConfig.baseUrl,
    ),
  );
  await tester.pumpAndSettle();
  testConfig.assertSessionCreated(tester);

  expect(find.byType(Row), findsWidgets);
  expect(find.byType(TextField), findsOneWidget);
  expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  expect(find.text('Type a message...'), findsOneWidget);
}

Future<void> testChartRendering(
  WidgetTester tester, {
  TestConfig? config,
}) async {
  final sentMessages = <String>[];

  final testConfig =
      config ??
      (
        client: createMockClient(
          onCreateSession: () => successSessionResponse(id: 'chart-session'),
          onSendMessage: (msg) {
            sentMessages.add(msg);
            return switch (msg.toLowerCase()) {
              final m when m.contains('bar') && m.contains('population') =>
                chatResponseWithChart(
                  response: 'Here is a bar chart of populations:',
                  title: 'Population by Country',
                ),
              final m when m.contains('line') && m.contains('gdp') =>
                chatResponseWithChart(
                  response: 'Here is a line chart of GDP:',
                  chartType: 'line',
                  title: 'GDP Growth Over Time',
                ),
              final m when m.contains('pie') && m.contains('region') =>
                chatResponseWithChart(
                  response: 'Here is a pie chart of regions:',
                  chartType: 'pie',
                  title: 'Countries by Region',
                ),
              _ => successChatResponse(response: 'No chart requested'),
            };
          },
        ),
        baseUrl: defaultBaseUrl,
        assertSessionCreated: mockSessionAssertion,
        assertResponseReceived: createMockResponseAssertion(
          expectedResponses: {},
        ),
      );

  await tester.pumpWidget(
    _TestApp(
      logging: createLoggingContext(),
      client: testConfig.client,
      baseUrl: testConfig.baseUrl,
    ),
  );
  await tester.pumpAndSettle();
  testConfig.assertSessionCreated(tester);

  await tester.enterText(
    find.byType(TextField),
    'Show a bar chart of population for 5 countries',
  );
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  if (config == null) {
    expect(
      sentMessages,
      contains('Show a bar chart of population for 5 countries'),
    );
    expect(find.text('Population by Country'), findsOneWidget);
    expect(find.byType(charts.BarChart), findsOneWidget);
  }
  testConfig.assertResponseReceived(
    tester,
    'Show a bar chart of population for 5 countries',
  );

  await tester.enterText(
    find.byType(TextField),
    'Now show a line chart of GDP for European countries',
  );
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  if (config == null) {
    expect(
      sentMessages,
      contains('Now show a line chart of GDP for European countries'),
    );
    expect(find.text('GDP Growth Over Time'), findsOneWidget);
    expect(find.byType(charts.LineChart), findsOneWidget);
  }
  testConfig.assertResponseReceived(
    tester,
    'Now show a line chart of GDP for European countries',
  );

  await tester.enterText(
    find.byType(TextField),
    'Show a pie chart of countries by region',
  );
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();

  if (config == null) {
    expect(sentMessages, contains('Show a pie chart of countries by region'));
    expect(find.text('Countries by Region'), findsOneWidget);
    expect(find.byType(charts.PieChart<String>), findsOneWidget);
    expect(sentMessages.length, 3);
  }
  testConfig.assertResponseReceived(
    tester,
    'Show a pie chart of countries by region',
  );
}

Future<void> _goldenEmptyState(WidgetTester tester, String sizeName) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) => successChatResponse(),
  );
  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/empty_state_$sizeName.png'),
  );
}

Future<void> _goldenWithMessages(WidgetTester tester, String sizeName) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) => successChatResponse(response: 'Hello there!'),
  );
  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Hi');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/with_messages_$sizeName.png'),
  );
}

Future<void> _goldenWithChart(WidgetTester tester, String sizeName) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) =>
        chatResponseWithChart(response: 'Chart:', title: 'Data'),
  );
  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'chart');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/with_chart_$sizeName.png'),
  );
}

Future<void> _goldenWithAuthCard(WidgetTester tester, String sizeName) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) => chatResponseWithAuthRequired(
      response: 'Please sign in:',
      authUrl: 'https://example.com/oauth',
    ),
  );
  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'auth');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/with_auth_card_$sizeName.png'),
  );
}

Future<void> _goldenWithImage(WidgetTester tester, String sizeName) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) => chatResponseWithImage(
      response: 'Image:',
      imageUrl: 'https://example.com/img.png',
    ),
  );
  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'image');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/with_image_$sizeName.png'),
  );
}

Future<void> _goldenWithFile(WidgetTester tester, String sizeName) async {
  final client = createMockClient(
    onCreateSession: successSessionResponse,
    onSendMessage: (_) =>
        chatResponseWithFile(response: 'File:', name: 'doc.pdf'),
  );
  await tester.pumpWidget(
    _TestApp(logging: createLoggingContext(), client: client),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'file');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/with_file_$sizeName.png'),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.logging,
    required this.client,
    this.baseUrl = defaultBaseUrl,
  });

  final LoggingContext logging;
  final http.Client client;
  final String baseUrl;

  @override
  Widget build(BuildContext context) =>
      AgentChatApp(logging: logging, httpClient: client, baseUrl: baseUrl);
}
