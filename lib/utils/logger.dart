import 'package:colored_logger/colored_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class Logger {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final String? _name;
  final int _maxHistorySize;
  final List<String> _history = [];

  Logger(this._name, {int maxHistorySize = 100})
    : _maxHistorySize = maxHistorySize;

  void _addToHistory(String message) {
    if (_maxHistorySize <= 0) return;
    _history.add('${DateFormat('HH:mm:ss').format(DateTime.now())} $message');
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  void i(dynamic message) {
    final msg0 = message.toString();
    _addToHistory('[INFO] $msg0');
    if (kDebugMode) {
      final msg = msg0;
      ColoredLogger.info(
        msg,
        prefix: '${_dateFormat.format(DateTime.now())}    [INFO] $_name: ',
      );
    }
  }

  void e(dynamic message, {StackTrace? stackTrace}) {
    final msg0 = message.toString();
    _addToHistory('[ERROR] $msg0');
    if (stackTrace != null) _addToHistory('[STACKTRACE] $stackTrace');
    if (kDebugMode) {
      final msg = msg0;
      ColoredLogger.error(
        msg,
        prefix: '${_dateFormat.format(DateTime.now())}   [ERROR] $_name: ',
      );
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace, label: _name);
      }
    }
  }

  void w(dynamic message) {
    final msg0 = message.toString();
    _addToHistory('[WARNING] $msg0');
    if (kDebugMode) {
      final msg = msg0;
      ColoredLogger.warning(
        msg,
        prefix: '${_dateFormat.format(DateTime.now())} [WARNING] $_name: ',
      );
    }
  }

  void d(dynamic message) {
    final msg0 = message.toString();
    _addToHistory('[DEBUG] $msg0');
    if (kDebugMode) {
      final msg = msg0;
      ColoredLogger.colorize(
        msg,
        prefix: '${_dateFormat.format(DateTime.now())}   [DEBUG] $_name: ',
        styles: [Ansi.bold, Ansi.brightBlue],
      );
    }
  }

  String getHistory() => _history.join("\n");

  void clearHistory() => _history.clear();

  void testLogger() {
    i('This is an info message');
    e('This is an error message');
    w('This is a warning message');
    d('This is a debug message');
  }
}

class MemoryLogger {
  StringBuffer logs = StringBuffer();

  void log(String message) {
    logs.write('${DateTime.now().toIso8601String().split(".")[0]}| $message\n');
  }

  void write(String message) {
    logs.write('$message\n');
  }
}

Logger logger = Logger('Lanis', maxHistorySize: 400);
Logger backgroundLogger = Logger('Lanis BG', maxHistorySize: 200);
