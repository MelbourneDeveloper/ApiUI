import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Assertion function for verifying response after a message
typedef ResponseAssertion = void Function(WidgetTester tester, String sentMsg);

/// Assertion function for verifying session creation
typedef SessionAssertion = void Function(WidgetTester tester);

/// Configuration for test execution - supports both mock and real backends
typedef TestConfig = ({
  http.Client client,
  String baseUrl,
  SessionAssertion assertSessionCreated,
  ResponseAssertion assertResponseReceived,
});

/// Mock assertions - check exact response text
void mockSessionAssertion(WidgetTester tester) {
  expect(find.byType(ListView), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);
}

/// Mock response assertion - checks for specific text based on message
ResponseAssertion createMockResponseAssertion({
  required Map<String, String> expectedResponses,
}) => (tester, sentMsg) {
  final key = expectedResponses.keys.firstWhere(
    (k) => sentMsg.toLowerCase().contains(k),
    orElse: () => '',
  );
  final expected = expectedResponses[key];
  if (expected != null) {
    expect(find.textContaining(expected), findsOneWidget);
  }
  // Loading indicator should be gone
  expect(find.byType(LinearProgressIndicator), findsNothing);
};

// Type aliases for mock factories - inject these to control API behavior
typedef SessionResponseFactory = http.Response Function();
typedef ChatResponseFactory = http.Response Function(String message);
typedef AuthTokenResponseFactory =
    http.Response Function(String sessionId, String provider, String token);

// Mock client factory - returns configured MockClient
http.Client createMockClient({
  required SessionResponseFactory onCreateSession,
  required ChatResponseFactory onSendMessage,
  AuthTokenResponseFactory? onAuthToken,
}) => MockClient((request) async {
  // Simulate network delay
  await Future<void>.delayed(const Duration(milliseconds: 50));

  return switch (request.url.path) {
    '/session' => onCreateSession(),
    '/chat' => onSendMessage(
      (jsonDecode(request.body) as Map<String, dynamic>)['message'] as String,
    ),
    '/auth/token' when onAuthToken != null => () {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return onAuthToken(
        body['session_id'] as String,
        body['provider'] as String,
        body['token'] as String,
      );
    }(),
    '/auth/token' => http.Response('{}', 200),
    _ => http.Response('Not Found', 404),
  };
});

// Response factories for common scenarios
http.Response successSessionResponse({String id = 'test-session-123'}) =>
    http.Response(jsonEncode({'id': id, 'message_count': 0}), 200);

http.Response errorSessionResponse({int statusCode = 500}) =>
    http.Response('Error', statusCode);

http.Response successChatResponse({
  String response = 'Hello from assistant!',
  List<Map<String, dynamic>> toolOutputs = const [],
}) => http.Response(
  jsonEncode({
    'session_id': 'test-session-123',
    'response': response,
    'tool_outputs': toolOutputs,
  }),
  200,
);

http.Response errorChatResponse({int statusCode = 500}) =>
    http.Response('Error', statusCode);

http.Response chatResponseWithImage({
  String response = 'Here is an image:',
  String imageUrl = 'https://example.com/image.png',
  String alt = 'Test image',
}) => http.Response(
  jsonEncode({
    'session_id': 'test-session-123',
    'response': response,
    'tool_outputs': [
      {'type': 'image', 'url': imageUrl, 'alt': alt},
    ],
  }),
  200,
);

http.Response chatResponseWithLink({
  String response = 'Here is a link:',
  String url = 'https://example.com',
  String title = 'Example',
}) => http.Response(
  jsonEncode({
    'session_id': 'test-session-123',
    'response': response,
    'tool_outputs': [
      {'type': 'link', 'url': url, 'title': title},
    ],
  }),
  200,
);

http.Response chatResponseWithChart({
  String response = 'Here is a chart:',
  String chartType = 'bar',
  String title = 'Test Chart',
}) => http.Response(
  jsonEncode({
    'session_id': 'test-session-123',
    'response': response,
    'tool_outputs': [
      {
        'type': 'chart',
        'chart_type': chartType,
        'title': title,
        'data': [
          {'x': 1, 'y': 10},
          {'x': 2, 'y': 20},
        ],
        'x_label': 'X',
        'y_label': 'Y',
      },
    ],
  }),
  200,
);

http.Response chatResponseWithFile({
  String response = 'Here is a file:',
  String name = 'test.txt',
  String content = 'file content',
}) => http.Response(
  jsonEncode({
    'session_id': 'test-session-123',
    'response': response,
    'tool_outputs': [
      {
        'type': 'file',
        'name': name,
        'content': content,
        'mime_type': 'text/plain',
      },
    ],
  }),
  200,
);

http.Response chatResponseWithAuthRequired({
  String response = 'Auth needed:',
  String provider = 'google',
  String authUrl = 'https://auth.example.com/oauth',
}) => http.Response(
  jsonEncode({
    'session_id': 'test-session-123',
    'response': response,
    'tool_outputs': [
      {'type': 'auth_required', 'provider': provider, 'auth_url': authUrl},
    ],
  }),
  200,
);
