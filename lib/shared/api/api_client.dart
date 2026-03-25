import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'api_logger.dart';
import 'api_response.dart';

class ApiClient {
  const ApiClient({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    final merged = Map<String, String>.from(uri.queryParameters);
    for (final e in queryParameters.entries) {
      merged[e.key] = e.value;
    }
    return uri.replace(queryParameters: merged);
  }

  Future<ApiResponse> postJson(
    String path, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
    Set<String> redactKeys = const {'password'},
  }) async {
    final uri = _uri(path);
    final method = 'POST';

    final sanitizedBody = <String, dynamic>{
      for (final entry in body.entries)
        entry.key: redactKeys.contains(entry.key) ? '***' : entry.value,
    };

    ApiLogger.logRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: sanitizedBody,
    );

    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(uri);
      request.headers.contentType = ContentType.json;
      headers?.forEach(request.headers.add);
      request.write(jsonEncode(body));

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();

      final headersMap = <String, List<String>>{};
      response.headers.forEach(
        (name, values) => headersMap[name.toLowerCase()] = List<String>.from(
          values,
          growable: false,
        ),
      );

      Map<String, dynamic> json = <String, dynamic>{};
      if (rawBody.isNotEmpty) {
        final dynamic decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      }

      ApiLogger.logResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        headers: headersMap,
        body: rawBody,
      );

      return ApiResponse(
        statusCode: response.statusCode,
        rawBody: rawBody,
        json: json,
        headers: headersMap,
      );
    } catch (e, st) {
      ApiLogger.logError(method: method, uri: uri, error: e, stackTrace: st);
      rethrow;
    } finally {
      httpClient.close(force: true);
    }
  }

  /// DELETE 요청을 보내고 JSON 응답을 반환합니다.
  /// [body]가 있으면 `Content-Type: application/json`으로 직렬화해 보냅니다.
  Future<ApiResponse> deleteJson(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Set<String> redactKeys = const {'password'},
  }) async {
    final uri = _uri(path);
    const method = 'DELETE';

    final Map<String, dynamic>? sanitizedBody = body == null
        ? null
        : {
            for (final entry in body.entries)
              entry.key: redactKeys.contains(entry.key) ? '***' : entry.value,
          };

    ApiLogger.logRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: sanitizedBody,
    );

    final httpClient = HttpClient();
    try {
      final request = await httpClient.openUrl(method, uri);
      if (body != null) {
        request.headers.contentType = ContentType.json;
      }
      headers?.forEach(request.headers.add);
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();

      final headersMap = <String, List<String>>{};
      response.headers.forEach(
        (name, values) => headersMap[name.toLowerCase()] = List<String>.from(
          values,
          growable: false,
        ),
      );

      Map<String, dynamic> json = <String, dynamic>{};
      if (rawBody.isNotEmpty) {
        final dynamic decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      }

      ApiLogger.logResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        headers: headersMap,
        body: rawBody,
      );

      return ApiResponse(
        statusCode: response.statusCode,
        rawBody: rawBody,
        json: json,
        headers: headersMap,
      );
    } catch (e, st) {
      ApiLogger.logError(method: method, uri: uri, error: e, stackTrace: st);
      rethrow;
    } finally {
      httpClient.close(force: true);
    }
  }

  /// PUT 요청을 보내고 JSON 응답을 반환합니다.
  Future<ApiResponse> putJson(
    String path, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
    Set<String> redactKeys = const {'password'},
  }) async {
    final uri = _uri(path);
    const method = 'PUT';

    final sanitizedBody = <String, dynamic>{
      for (final entry in body.entries)
        entry.key: redactKeys.contains(entry.key) ? '***' : entry.value,
    };

    ApiLogger.logRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: sanitizedBody,
    );

    final httpClient = HttpClient();
    try {
      final request = await httpClient.putUrl(uri);
      request.headers.contentType = ContentType.json;
      headers?.forEach(request.headers.add);
      request.write(jsonEncode(body));

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();

      final headersMap = <String, List<String>>{};
      response.headers.forEach(
        (name, values) => headersMap[name.toLowerCase()] = List<String>.from(
          values,
          growable: false,
        ),
      );

      Map<String, dynamic> json = <String, dynamic>{};
      if (rawBody.isNotEmpty) {
        final dynamic decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      }

      ApiLogger.logResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        headers: headersMap,
        body: rawBody,
      );

      return ApiResponse(
        statusCode: response.statusCode,
        rawBody: rawBody,
        json: json,
        headers: headersMap,
      );
    } catch (e, st) {
      ApiLogger.logError(method: method, uri: uri, error: e, stackTrace: st);
      rethrow;
    } finally {
      httpClient.close(force: true);
    }
  }

  /// PATCH 요청을 보내고 JSON 응답을 반환합니다.
  Future<ApiResponse> patchJson(
    String path, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
    Set<String> redactKeys = const {'password', 'currentPassword', 'newPassword'},
  }) async {
    final uri = _uri(path);
    const method = 'PATCH';

    final sanitizedBody = <String, dynamic>{
      for (final entry in body.entries)
        entry.key: redactKeys.contains(entry.key) ? '***' : entry.value,
    };

    ApiLogger.logRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: sanitizedBody,
    );

    final httpClient = HttpClient();
    try {
      final request = await httpClient.patchUrl(uri);
      request.headers.contentType = ContentType.json;
      headers?.forEach(request.headers.add);
      request.write(jsonEncode(body));

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();

      final headersMap = <String, List<String>>{};
      response.headers.forEach(
        (name, values) => headersMap[name.toLowerCase()] = List<String>.from(
          values,
          growable: false,
        ),
      );

      Map<String, dynamic> json = <String, dynamic>{};
      if (rawBody.isNotEmpty) {
        final dynamic decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      }

      ApiLogger.logResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        headers: headersMap,
        body: rawBody,
      );

      return ApiResponse(
        statusCode: response.statusCode,
        rawBody: rawBody,
        json: json,
        headers: headersMap,
      );
    } catch (e, st) {
      ApiLogger.logError(method: method, uri: uri, error: e, stackTrace: st);
      rethrow;
    } finally {
      httpClient.close(force: true);
    }
  }

  /// POST `multipart/form-data` (텍스트 필드 + 파일). 파일은 동일 [fileFieldName]로 여러 파트 가능.
  Future<ApiResponse> postMultipart(
    String path, {
    Map<String, String>? headers,
    required Map<String, String> fields,
    String fileFieldName = 'images',
    required List<({String filename, List<int> bytes, String contentType})> files,
  }) async {
    final uri = _uri(path);
    const method = 'POST';
    final boundary = 'dart-${DateTime.now().microsecondsSinceEpoch}';

    ApiLogger.logRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: {
        'multipart': true,
        'fields': fields,
        'files': [for (final f in files) f.filename],
      },
    );

    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      headers?.forEach((k, v) {
        final key = k.toLowerCase();
        if (key == 'content-type') return;
        request.headers.add(k, v);
      });

      final builder = BytesBuilder(copy: false);
      void addUtf8(String s) => builder.add(utf8.encode(s));

      for (final e in fields.entries) {
        addUtf8('--$boundary\r\n');
        addUtf8('Content-Disposition: form-data; name="${e.key}"\r\n\r\n');
        addUtf8(e.value);
        addUtf8('\r\n');
      }
      for (final f in files) {
        addUtf8('--$boundary\r\n');
        addUtf8(
          'Content-Disposition: form-data; name="$fileFieldName"; filename="${f.filename}"\r\n',
        );
        addUtf8('Content-Type: ${f.contentType}\r\n\r\n');
        builder.add(f.bytes);
        addUtf8('\r\n');
      }
      addUtf8('--$boundary--\r\n');

      request.add(builder.takeBytes());

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();

      final headersMap = <String, List<String>>{};
      response.headers.forEach(
        (name, values) => headersMap[name.toLowerCase()] = List<String>.from(
          values,
          growable: false,
        ),
      );

      Map<String, dynamic> json = <String, dynamic>{};
      if (rawBody.isNotEmpty) {
        try {
          final dynamic decoded = jsonDecode(rawBody);
          if (decoded is Map<String, dynamic>) {
            json = decoded;
          }
        } catch (_) {}
      }

      ApiLogger.logResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        headers: headersMap,
        body: rawBody,
      );

      return ApiResponse(
        statusCode: response.statusCode,
        rawBody: rawBody,
        json: json,
        headers: headersMap,
      );
    } catch (e, st) {
      ApiLogger.logError(method: method, uri: uri, error: e, stackTrace: st);
      rethrow;
    } finally {
      httpClient.close(force: true);
    }
  }

  /// GET 요청을 보내고 JSON 응답을 반환합니다.
  /// [path] 예: '/api/v1/vintages'
  /// [headers] 예: {'access': 'xxx'} — 인증 시 access 토큰을 그대로 넣으면 됨
  Future<ApiResponse> getJson(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _uri(path, queryParameters);
    const method = 'GET';

    ApiLogger.logRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: null,
    );

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      headers?.forEach(request.headers.add);

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();

      final headersMap = <String, List<String>>{};
      response.headers.forEach(
        (name, values) => headersMap[name.toLowerCase()] = List<String>.from(
          values,
          growable: false,
        ),
      );

      Map<String, dynamic> json = <String, dynamic>{};
      if (rawBody.isNotEmpty) {
        final dynamic decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      }

      ApiLogger.logResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        headers: headersMap,
        body: rawBody,
      );

      return ApiResponse(
        statusCode: response.statusCode,
        rawBody: rawBody,
        json: json,
        headers: headersMap,
      );
    } catch (e, st) {
      ApiLogger.logError(method: method, uri: uri, error: e, stackTrace: st);
      rethrow;
    } finally {
      httpClient.close(force: true);
    }
  }
}

