import 'package:nadz/nadz.dart';

/// A function that can be retried.
typedef RetryFunction<R> = Future<R> Function();

/// Error returned when all retry attempts fail.
typedef RetryError = ({int attempts, Object lastError});

/// Extension to retry a list of functions until one succeeds.
extension RetryExtensions<R> on List<RetryFunction<R>> {
  /// Retries functions in the list until one succeeds or maxTries is exceeded.
  Future<Result<R, RetryError>> retry({
    bool Function(R)? validResult,
    void Function(int attempt, Object error, R? result)? onInvalid,
    Duration Function(int attempt, Object? error)? delay,
    int maxTries = 5,
  }) async {
    Object lastError = Exception('No attempts made');
    var functionIndex = 0;
    final getDelay = delay ?? (i, _) => Duration(milliseconds: i * 100);

    for (var i = 0; i < maxTries; i++) {
      final attemptResult = await _tryAttempt(functionIndex, validResult);

      final result = switch (attemptResult) {
        Success(value: final r) => Success<R, RetryError>(r),
        Error(error: final e) => () {
          lastError = e;
          onInvalid?.call(i, e, null);
          return null;
        }(),
      };

      if (result != null) return result;

      await Future<void>.delayed(getDelay(i, lastError));
      functionIndex = (functionIndex + 1) % length;
    }

    return Error((attempts: maxTries, lastError: lastError));
  }

  Future<Result<R, Object>> _tryAttempt(
    int functionIndex,
    bool Function(R)? validResult,
  ) async {
    try {
      final result = await this[functionIndex]();
      return (validResult == null || validResult(result))
          ? Success(result)
          : Error(Exception('Invalid result'));
      // Catching all exceptions is necessary for retry logic to handle any
      // failure type from the user-provided functions.
    } on Object catch (e) {
      return Error(e);
    }
  }
}
