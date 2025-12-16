import 'package:flutter_app/src/api_client.dart';
import 'package:flutter_app/src/logging/logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nadz/nadz.dart';

void main() {
  test('postResult returns error when mock throws exception', () async {
    final client = MockClient((request) {
      throw Exception('Connection refused');
    });

    final result = await client.postResult<String, int>(
      'http://localhost:8000/session',
      logging: createLoggingContext(),
      onSuccess: (json) => Success(json['id'] as String),
      onError: (statusCode, body) => statusCode,
    );

    expect(result.isError, isTrue);
  });

  test(
    'postResult returns error when real client hits non-existent server',
    () async {
      final client = http.Client();

      final result = await client.postResult<String, int>(
        'http://127.0.0.1:59999/session',
        logging: createLoggingContext(),
        onSuccess: (json) => Success(json['id'] as String),
        onError: (statusCode, body) => statusCode,
      );

      expect(result.isError, isTrue);
    },
  );
}
