import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// `flutter run --dart-define=API_LOG=true` 로 릴리즈에서도 API 로그 켜기
const bool _kApiLogFromEnv =
    bool.fromEnvironment('API_LOG', defaultValue: false);

class ApiLogSanitizer {
  ApiLogSanitizer._();

  static const _sensitiveHeaders = {
    'access',
    'authorization',
    'cookie',
    'set-cookie',
  };

  static Map<String, String> requestHeaders(Map<String, String> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: _isSensitive(entry.key) ? '***' : entry.value,
    };
  }

  static Map<String, List<String>> responseHeaders(
    Map<String, List<String>> headers,
  ) {
    return {
      for (final entry in headers.entries)
        entry.key: _isSensitive(entry.key)
            ? const <String>['***']
            : List<String>.from(entry.value, growable: false),
    };
  }

  static bool _isSensitive(String name) {
    return _sensitiveHeaders.contains(name.toLowerCase());
  }
}

class ApiLogger {
  static bool get _enabled =>
      kDebugMode || kProfileMode || _kApiLogFromEnv;

  static void _line(String message) {
    if (!_enabled) return;
    developer.log(message, name: 'API');
    // `flutter run`이 붙은 터미널에는 [print]가 가장 잘 보임.
    // debugPrint는 throttle 되고, developer.log는 DevTools 쪽에 치우침.
    // ignore: avoid_print — 의도적으로 API 추적용
    print(message);
  }

  static void logRequest({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
  }) {
    if (!_enabled) return;
    _line('[API][REQ] $method $uri');
    if (headers != null && headers.isNotEmpty) {
      _line(
        '[API][REQ][headers] ${ApiLogSanitizer.requestHeaders(headers)}',
      );
    }
    if (body != null) {
      _line('[API][REQ][body] $body');
    }
  }

  static void logResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    Map<String, List<String>>? headers,
    required String body,
  }) {
    if (!_enabled) return;
    _line('[API][RES] $method $uri');
    _line('[API][RES][status] $statusCode');
    if (headers != null && headers.isNotEmpty) {
      _line(
        '[API][RES][headers] ${ApiLogSanitizer.responseHeaders(headers)}',
      );
    }
    _line('[API][RES][body] $body');
  }

  static void logError({
    required String method,
    required Uri uri,
    required Object error,
    StackTrace? stackTrace,
  }) {
    if (!_enabled) return;
    _line('[API][ERR] $method $uri');
    _line('[API][ERR] $error');
    if (stackTrace != null) {
      _line('[API][ERR][stack] $stackTrace');
    }
  }
}

