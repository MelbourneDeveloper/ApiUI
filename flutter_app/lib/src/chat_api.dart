import 'package:flutter_app/src/api_client.dart';
import 'package:flutter_app/src/logging/logging.dart';
import 'package:flutter_app/src/models.dart';
import 'package:http/http.dart' as http;
import 'package:nadz/nadz.dart';

/// Default base URL for the chat API server.
const defaultBaseUrl = 'http://localhost:8000';

/// Default error handler that returns the status code.
int _defaultOnError(int statusCode, Map<String, dynamic>? body) => statusCode;

/// Create a new session on the server.
Future<Result<SessionInfo, int>> createSession({
  required http.Client client,
  required LoggingContext logging,
  String baseUrl = defaultBaseUrl,
}) => client.postResult<SessionInfo, int>(
  '$baseUrl/session',
  logging: logging,
  onSuccess: (json) => Success((
    id: json['id'] as String,
    messageCount: json['message_count'] as int,
  )),
  onError: _defaultOnError,
);

/// Send a chat message and get a response.
Future<Result<ChatResponse, int>> sendMessage({
  required http.Client client,
  required String sessionId,
  required String message,
  required LoggingContext logging,
  String baseUrl = defaultBaseUrl,
}) => client.postResult<ChatResponse, int>(
  '$baseUrl/chat',
  logging: logging,
  body: {'session_id': sessionId, 'message': message},
  onSuccess: (json) => Success((
    sessionId: json['session_id'] as String,
    response: json['response'] as String,
    toolOutputs: (json['tool_outputs'] as List)
        .map((e) => DisplayContent.fromJson(e as Map<String, dynamic>))
        .toList(),
  )),
  onError: _defaultOnError,
);
