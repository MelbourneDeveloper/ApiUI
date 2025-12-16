// coverage:ignore-file

import 'package:flutter_app/src/logging/logging.dart' show LogFn, LogLevel;

/// Syntactic sugar for calling a [LogFn] with specific levels
extension LogFnExtensions on LogFn {
  /// Logs a trace-level message.
  void trace(
    String message, {
    Map<String, dynamic>? structuredData,
    List<String>? tags,
  }) => this(
    message,
    structuredData: structuredData,
    tags: tags,
    level: LogLevel.trace,
  );

  /// Logs a debug-level message.
  void debug(
    String message, {
    Map<String, dynamic>? structuredData,
    List<String>? tags,
  }) => this(
    message,
    structuredData: structuredData,
    tags: tags,
    level: LogLevel.debug,
  );

  /// Logs an info-level message.
  void info(
    String message, {
    Map<String, dynamic>? structuredData,
    List<String>? tags,
  }) => this(
    message,
    structuredData: structuredData,
    tags: tags,
    level: LogLevel.info,
  );

  /// Logs a warning-level message.
  void warn(
    String message, {
    Map<String, dynamic>? structuredData,
    List<String>? tags,
  }) => this(
    message,
    structuredData: structuredData,
    tags: tags,
    level: LogLevel.warn,
  );

  /// Logs an error-level message.
  void error(
    String message, {
    Map<String, dynamic>? structuredData,
    List<String>? tags,
  }) => this(
    message,
    structuredData: structuredData,
    tags: tags,
    level: LogLevel.error,
  );

  /// Logs a fatal-level message.
  void fatal(
    String message, {
    Map<String, dynamic>? structuredData,
    List<String>? tags,
  }) => this(
    message,
    structuredData: structuredData,
    tags: tags,
    level: LogLevel.fatal,
  );
}
