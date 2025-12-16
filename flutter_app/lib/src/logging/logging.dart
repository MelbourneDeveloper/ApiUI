// coverage:ignore-file

import 'dart:async';

/// Represents a fault that occurred during program execution
sealed class Fault {
  const Fault._internal(this.stackTrace);

  /// Creates a [Fault] from an object and stack trace
  factory Fault.fromObjectAndStackTrace(Object object, StackTrace stackTrace) =>
      switch (object) {
        final Exception ex => ExceptionFault(ex, stackTrace),
        final Error err => ErrorFault(err, stackTrace),
        final String text => MessageFault(text, stackTrace),
        _ => UnknownFault(object.toString(), stackTrace),
      };

  /// The stack trace associated with this fault
  final StackTrace stackTrace;

  @override
  String toString() => switch (this) {
    final ExceptionFault f => 'Exception: ${f.exception}',
    final ErrorFault f => 'Error: ${f.error}',
    final MessageFault f => 'Message: ${f.text}',
    final UnknownFault f => 'Unknown: ${f.object}',
  };
}

/// Represents a fault caused by an [Exception]
final class ExceptionFault extends Fault {
  /// Creates an [ExceptionFault] with the given exception and stack trace.
  const ExceptionFault(this.exception, StackTrace stackTrace)
    : super._internal(stackTrace);

  /// The underlying exception
  final Exception exception;
}

/// Represents a fault caused by an [Error]
final class ErrorFault extends Fault {
  /// Creates an [ErrorFault] with the given error and stack trace.
  const ErrorFault(this.error, StackTrace stackTrace)
    : super._internal(stackTrace);

  /// The underlying error
  final Object error;
}

/// Represents a fault with a text message
final class MessageFault extends Fault {
  /// Creates a [MessageFault] with the given text and stack trace.
  const MessageFault(this.text, StackTrace stackTrace)
    : super._internal(stackTrace);

  /// The fault message
  final String text;
}

/// Represents an unknown fault type
final class UnknownFault extends Fault {
  /// Creates an [UnknownFault] with the given object and stack trace.
  const UnknownFault(this.object, StackTrace stackTrace)
    : super._internal(stackTrace);

  /// The unknown object that caused the fault
  final Object? object;
}

/// The ANSI color codes for the log levels
const String _red = '\x1B[31m';
const String _green = '\x1B[32m';
const String _deepBlue = '\x1B[38;5;27m';
const String _orange = '\x1B[38;5;214m';

/// The severity of the log message
/// The level of the log message
enum LogLevel {
  /// Trace message (very detailed)
  trace(_deepBlue),

  /// Debug message (detailed)
  debug(_deepBlue),

  /// Informational message (important information)
  info(_green),

  /// Warning message
  warn(_orange),

  /// Error message
  error(_red),

  /// Fatal message
  fatal(_red);

  const LogLevel(this.ansiColor);

  /// The ANSI color code for the severity
  final String ansiColor;
}

/// A log message
typedef LogMessage = ({
  String message,
  LogLevel logLevel,
  Map<String, dynamic>? structuredData,
  StackTrace? stackTrace,
  Fault? fault,
  List<String>? tags,
  DateTime timestamp,
});

/// A simple log function signature that requires no external configuration
/// and can be curried from a [LoggingContext].
typedef LogFn =
    void Function(
      String message, {
      required LogLevel level,
      Map<String, dynamic>? structuredData,
      List<String>? tags,
    });

/// A function that logs a [LogMessage]
typedef LogFunction = void Function(LogMessage, LogLevel minimumlogLevel);

/// A logger with a log function and initialization callback.
typedef Logger = ({LogFunction log, Future<void> Function() initialize});

/// Creates a logger with the specified log function and optional initialization
Logger logger(LogFunction log, {Future<void> Function()? initialize}) =>
    (log: log, initialize: initialize ?? () async {});

/// The context that keeps track of the loggers
typedef LoggingContext = ({
  List<Logger> loggers,
  LogLevel minimumlogLevel,
  List<String> extraTags,
});

/// Creates a new [LoggingContext] with the specified configuration.
LoggingContext createLoggingContext({
  List<Logger>? loggers,
  LogLevel? minimumlogLevel,
  List<String>? extraTags,
}) => (
  loggers: loggers ?? [],
  minimumlogLevel: minimumlogLevel ?? LogLevel.info,
  extraTags: extraTags ?? [],
);

/// Processes a message template by replacing placeholders with values from
/// structured data
///
/// Template format: "Text with {placeholder}" where placeholder is a key in
/// structuredData
/// Example: processTemplate("User {id} logged in", {"id": "123"}) =>
/// "User 123 logged in"
String processTemplate(String template, Map<String, dynamic>? structuredData) {
  if (structuredData == null || structuredData.isEmpty) {
    return template;
  }

  var result = template;
  for (final entry in structuredData.entries) {
    result = result.replaceAll('{${entry.key}}', '${entry.value}');
  }

  return result;
}

/// Extensions for the [LoggingContext]
extension LoggingContextExtensions on LoggingContext {
  /// Iterates through loggers and logs the message
  void log(
    String message, {
    LogLevel logLevel = LogLevel.trace,
    Fault? fault,
    Map<String, dynamic>? structuredData,
    StackTrace? stackTrace,
    List<String>? tags,
  }) {
    final processedMessage = processTemplate(message, structuredData);

    final logMessage = (
      message: processedMessage,
      logLevel: logLevel,
      fault: fault,
      tags: tags,
      structuredData: structuredData,
      stackTrace: stackTrace,
      timestamp: DateTime.now().toUtc(),
    );

    for (final logger in loggers) {
      logger.log(logMessage, minimumlogLevel);
    }
  }

  /// Makes a copy of the logging context
  LoggingContext copyWith({
    List<Logger>? loggers,
    LogLevel? minimumlogLevel,
    List<String>? extraTags,
  }) => (
    loggers: loggers ?? this.loggers,
    minimumlogLevel: minimumlogLevel ?? this.minimumlogLevel,
    extraTags: extraTags ?? this.extraTags,
  );

  /// Executes an action, logs the start and end of the action, and returns the
  /// result of the action
  Future<T> logged<T>(
    Future<T> action,
    String actionName, {
    bool logCallStack = false,
    ({String message, Map<String, dynamic>? structuredData, LogLevel level})
    Function(T result, int elapsedMilliseconds)?
    resultFormatter,
    List<String>? tags,
  }) async {
    log('Start $actionName');
    if (logCallStack) {
      log('Call Stack\n${StackTrace.current}');
    }
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action;

      final formatterResult =
          resultFormatter?.call(result, stopwatch.elapsedMilliseconds) ??
          (message: result, structuredData: {}, level: LogLevel.trace);

      log(
        logLevel: formatterResult.level,
        'Completed $actionName with no exceptions in '
        '${stopwatch.elapsedMilliseconds}ms with '
        '${formatterResult.message}',
        structuredData: formatterResult.structuredData,
        tags: tags,
      );

      return result;
    } catch (e, s) {
      log(
        'Failed $actionName in ${stopwatch.elapsedMilliseconds}ms',
        logLevel: LogLevel.error,
        fault: Fault.fromObjectAndStackTrace(e, s),
      );
      rethrow;
    }
  }

  /// Initializes all loggers in this context.
  Future<void> initialize() async {
    for (final logger in loggers) {
      //TODO: this aint right
      unawaited(logger.initialize());
    }
  }
}

//final bool _useColors = !kIsWeb && !Platform.isIOS;

/// Extension for nullable types to provide let-style operations.
extension NullableExtensions<T> on T? {
  /// Calls the function if the value is not null.
  void let(void Function(T) fn) {
    if (this is T) {
      fn(this as T);
    }
  }

  /// Maps the value using the function, assuming non-null.
  R let2<R>(R Function(T) fn) => fn(this as T);
}
