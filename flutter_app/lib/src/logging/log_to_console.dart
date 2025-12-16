// Print statements are intentional for console logging output.
// ignore_for_file: avoid_print

// coverage:ignore-file

import 'dart:io';

import 'package:flutter_app/src/logging/logging.dart';

//-------- Console Logger --------

const String _reset = '\x1B[0m';

final bool _useColors = !Platform.isIOS;

/// Formats a message with ANSI color codes based on severity level
String _formatMessage(String message, LogLevel severity) {
  if (_useColors) {
    return '${severity.ansiColor} $message$_reset';
  }
  return message;
}

/// Logs a message to the console with formatting and structured data
void logToConsole(LogMessage message, LogLevel minimumlogLevel) {
  final timestamp = DateTime.now().toIso8601String().substring(11, 19);
  final levelIcon = switch (message.logLevel) {
    LogLevel.trace => '🔎',
    LogLevel.debug => '🔍',
    LogLevel.info => 'ℹ️ ',
    LogLevel.warn => '⚠️ ',
    LogLevel.error => '❌',
    LogLevel.fatal => '🚨',
  };

  final tagStr = (message.tags?.isNotEmpty ?? false)
      ? '[${message.tags!.join(',')}] '
      : '';
  const prefixStr = '';

  print('$timestamp $levelIcon $prefixStr$tagStr${message.message}');

  if (message.structuredData?.isNotEmpty ?? false) {
    for (final entry in message.structuredData!.entries) {
      print('  └─ ${entry.key}: ${entry.value}');
    }
  }

  message.fault.let(
    (s) => print(_formatMessage('***** Fault *****\n$s', message.logLevel)),
  );

  message.stackTrace.let(
    (s) =>
        print(_formatMessage('***** Stack Trace *****\n$s', message.logLevel)),
  );
}

/// LogFn compatible function that uses the merged logging approach
void logToConsoleFormatted(
  String message, {
  required LogLevel level,
  Map<String, dynamic>? structuredData,
  List<String>? tags,
}) {
  final logMessage = (
    message: message,
    logLevel: level,
    fault: null,
    tags: tags,
    structuredData: structuredData,
    stackTrace: null,
    timestamp: DateTime.now().toUtc(),
  );

  logToConsole(logMessage, LogLevel.trace);
}
