import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error }

class AppLogger {
  AppLogger._();

  /// Logs informational messages.
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Logs warnings (e.g. recoverable errors, unexpected behavior).
  static void warning(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }

  /// Logs critical errors and automatically reports them to Crashlytics.
  static void error(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.error, message, tag: tag);
    
    // Always report errors to Crashlytics
    FirebaseCrashlytics.instance.recordError(
      error ?? Exception(message),
      stackTrace,
      reason: message,
      fatal: false, // Non-fatal by default unless it crashes the app
    );
  }

  /// Track a user action (e.g. button click, screen open).
  /// This adds a custom breadcrumb to Crashlytics to help retrace steps.
  static void action(String actionName, {Map<String, dynamic>? parameters}) {
    final logMessage = 'Action: $actionName | Params: $parameters';
    _log(LogLevel.info, logMessage, tag: 'ACTION');
    FirebaseCrashlytics.instance.log(logMessage);
  }

  static void _log(LogLevel level, String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagPrefix = tag != null ? '[$tag] ' : '';
    final formattedMessage = '[$timestamp] ${level.name.toUpperCase()}: $tagPrefix$message';

    // Print to console in debug mode
    if (kDebugMode) {
      debugPrint(formattedMessage);
    }

    // Leave a breadcrumb in Crashlytics for all logs
    FirebaseCrashlytics.instance.log(formattedMessage);
  }
}
