import 'package:flutter/material.dart';
import 'package:flutter_app/src/chat_api.dart' show defaultBaseUrl;
import 'package:flutter_app/src/chat_screen.dart';
import 'package:flutter_app/src/logging/log_to_console.dart';
import 'package:flutter_app/src/logging/logging.dart';
import 'package:flutter_app/src/theme/app_theme.dart';
import 'package:flutter_app/src/theme/color_generator.dart' show appSeedHue;
import 'package:http/http.dart' as http;

void main() {
  final logging = createLoggingContext(
    loggers: [logger(logToConsole)],
    minimumlogLevel: LogLevel.trace,
  );

  runApp(AgentChatApp(logging: logging, httpClient: http.Client()));
}

/// Root widget for the Agent Chat application.
class AgentChatApp extends StatelessWidget {
  /// Creates the app with required logging and optional HTTP client for DI.
  const AgentChatApp({
    required this.logging,
    required this.httpClient,
    this.baseUrl = defaultBaseUrl,
    this.seedHue = appSeedHue,
    super.key,
  });

  /// Logging context for the application.
  final LoggingContext logging;

  /// HTTP client for dependency injection (testing).
  final http.Client httpClient;

  /// Base URL for API calls.
  final String baseUrl;

  /// Seed hue for color palette generation (0-360).
  final double seedHue;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Agent Chat',
    theme: buildLightTheme(seedHue),
    darkTheme: buildDarkTheme(seedHue),
    home: ChatScreen(
      logging: logging,
      httpClient: httpClient,
      baseUrl: baseUrl,
    ),
  );
}
