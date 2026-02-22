import 'package:flutter/foundation.dart';

class ApiLogger {
  static void logRequest({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
  }) {
    if (!kDebugMode) return;
    debugPrint('[API][REQ] $method $uri');
    if (headers != null && headers.isNotEmpty) {
      debugPrint('[API][REQ][headers] $headers');
    }
    if (body != null) {
      debugPrint('[API][REQ][body] $body');
    }
  }

  static void logResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    Map<String, List<String>>? headers,
    required String body,
  }) {
    if (!kDebugMode) return;
    debugPrint('[API][RES] $method $uri');
    debugPrint('[API][RES][status] $statusCode');
    if (headers != null && headers.isNotEmpty) {
      debugPrint('[API][RES][headers] $headers');
    }
    debugPrint('[API][RES][body] $body');
  }

  static void logError({
    required String method,
    required Uri uri,
    required Object error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint('[API][ERR] $method $uri');
    debugPrint('[API][ERR] $error');
    if (stackTrace != null) {
      debugPrint('[API][ERR][stack] $stackTrace');
    }
  }
}

