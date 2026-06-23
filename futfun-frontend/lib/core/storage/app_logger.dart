import 'package:flutter/foundation.dart';

/// In-memory circular log — last 200 entries, visible from the debug screen.
class AppLogger {
  static final _entries = <String>[];
  static const _maxEntries = 200;

  static void log(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final entry = '[$ts] $message';
    _entries.add(entry);
    if (_entries.length > _maxEntries) _entries.removeAt(0);
    debugPrint('[FutFun] $entry');
  }

  static List<String> get entries => List.unmodifiable(_entries);

  static String get dump => _entries.join('\n');

  static void clear() => _entries.clear();
}
