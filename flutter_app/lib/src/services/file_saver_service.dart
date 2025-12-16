import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

/// Function type for saving files.
typedef FileSaverFn = Future<void> Function({
  required String name,
  required String content,
});

/// Default file saver using file_saver package.
Future<void> defaultFileSaver({
  required String name,
  required String content,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  await FileSaver.instance.saveFile(name: name, bytes: bytes);
}

/// Current file saver function - can be overridden for testing.
FileSaverFn fileSaver = defaultFileSaver;
