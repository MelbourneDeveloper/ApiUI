import 'dart:convert';

import 'package:flutter_app/src/logging/logging.dart';
import 'package:flutter_app/src/retry.dart';
import 'package:http/http.dart' as http;
import 'package:nadz/nadz.dart';

/// Extensions on http.Client for API calls with retry and logging.
extension ApiClientExtensions on http.Client {
  /// POST request with retry and logging.
  Future<Result<T, E>> postResult<T, E>(
    String url, {
    required LoggingContext logging,
    required Result<T, E> Function(Map<String, dynamic>) onSuccess,
    required E Function(int statusCode, Map<String, dynamic>? body) onError,
    Map<String, dynamic>? body,
  }) => _callApi(
    url,
    logging: logging,
    onSuccess: onSuccess,
    onError: onError,
    request: () => post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    ),
  );

  Future<Result<T, E>> _callApi<T, E>(
    String url, {
    required LoggingContext logging,
    required Result<T, E> Function(Map<String, dynamic>) onSuccess,
    required E Function(int statusCode, Map<String, dynamic>? body) onError,
    required Future<http.Response> Function() request,
  }) async {
    Result<T, E>? lastResult;
    final response = await [
      () async {
        final response = await logging.logged(
          request(),
          url,
          resultFormatter: (r, e) => (
            message: 'Status ${r.statusCode}',
            structuredData: {
              'url': url,
              'elapsedMs': e.toString(),
              'statusCode': r.statusCode.toString(),
            },
            level: r.statusCode == 200 ? LogLevel.trace : LogLevel.error,
          ),
        );
        lastResult = response.statusCode == 200
            ? onSuccess(jsonDecode(response.body) as Map<String, dynamic>)
            : Error<T, E>(
                onError(response.statusCode, _tryParseJson(response.body)),
              );
        return lastResult!;
      },
    ].retry(validResult: (r) => r.isSuccess);
    return switch (response) {
      Success(value: final r) => r,
      Error(error: final e) =>
        lastResult ?? Error(onError(-1, {'error': e.lastError.toString()})),
    };
  }
}

Map<String, dynamic>? _tryParseJson(String body) {
  try {
    return jsonDecode(body) as Map<String, dynamic>;
  } on FormatException {
    return null;
  }
}
