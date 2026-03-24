// =============================================================================
// 인증 API 래퍼 (Authenticated API)
// =============================================================================
//
// access 토큰을 붙여서 API를 호출하고, 401이면 우선 reissue 후 한 번만 재시도합니다.
// 모든 인증 필요한 API는 이 래퍼를 사용하면 401 시 자동으로 reissue 후 재요청됩니다.
//
// 규칙: 모든 API에서 401이 뜨면 우선 reissue를 시도한 뒤, 성공 시 해당 요청을 한 번만 재시도.
// =============================================================================

import 'api_client.dart';
import 'api_response.dart';
import '../auth/token_reissue.dart';
import '../auth/token_storage.dart';

/// access 토큰을 헤더에 넣어 GET 요청을 보냅니다.
/// 응답이 401이면 reissue를 시도하고, 성공 시 같은 요청을 새 토큰으로 한 번만 재시도합니다.
/// 재시도 후에도 401이거나 reissue가 실패하면 그대로 401 응답을 반환합니다.
Future<ApiResponse> getJsonWithAuth(String baseUrl, String path) async {
  final token = await TokenStorage.getAccessToken();
  final api = ApiClient(baseUrl: baseUrl);
  final headers = token != null && token.isNotEmpty ? {'access': token} : null;

  ApiResponse response = await api.getJson(path, headers: headers);

  if (response.statusCode == 401) {
    final reissued = await reissueTokens(baseUrl);
    if (reissued) {
      final newToken = await TokenStorage.getAccessToken();
      if (newToken != null && newToken.isNotEmpty) {
        response = await api.getJson(path, headers: {'access': newToken});
      }
    }
  }

  return response;
}

/// access 토큰을 헤더에 넣어 DELETE 요청을 보냅니다.
/// 응답이 401이면 reissue를 시도하고, 성공 시 같은 요청을 새 토큰으로 한 번만 재시도합니다.
Future<ApiResponse> deleteWithAuth(
  String baseUrl,
  String path, {
  Map<String, dynamic>? body,
  Set<String> redactKeys = const {'password'},
}) async {
  final token = await TokenStorage.getAccessToken();
  final api = ApiClient(baseUrl: baseUrl);
  final headers = token != null && token.isNotEmpty ? {'access': token} : null;

  ApiResponse response = await api.deleteJson(
    path,
    headers: headers,
    body: body,
    redactKeys: redactKeys,
  );

  if (response.statusCode == 401) {
    final reissued = await reissueTokens(baseUrl);
    if (reissued) {
      final newToken = await TokenStorage.getAccessToken();
      if (newToken != null && newToken.isNotEmpty) {
        response = await api.deleteJson(
          path,
          headers: {'access': newToken},
          body: body,
          redactKeys: redactKeys,
        );
      }
    }
  }

  return response;
}

/// access 토큰을 헤더에 넣어 PUT 요청을 보냅니다.
/// 응답이 401이면 reissue를 시도하고, 성공 시 같은 요청을 새 토큰으로 한 번만 재시도합니다.
Future<ApiResponse> putJsonWithAuth(
  String baseUrl,
  String path, {
  required Map<String, dynamic> body,
  Set<String> redactKeys = const {'password'},
}) async {
  final token = await TokenStorage.getAccessToken();
  final api = ApiClient(baseUrl: baseUrl);
  final headers = token != null && token.isNotEmpty ? {'access': token} : null;

  ApiResponse response = await api.putJson(
    path,
    headers: headers,
    body: body,
    redactKeys: redactKeys,
  );

  if (response.statusCode == 401) {
    final reissued = await reissueTokens(baseUrl);
    if (reissued) {
      final newToken = await TokenStorage.getAccessToken();
      if (newToken != null && newToken.isNotEmpty) {
        response = await api.putJson(
          path,
          headers: {'access': newToken},
          body: body,
          redactKeys: redactKeys,
        );
      }
    }
  }

  return response;
}

/// access 토큰을 헤더에 넣어 PATCH 요청을 보냅니다.
/// 응답이 401이면 reissue를 시도하고, 성공 시 같은 요청을 새 토큰으로 한 번만 재시도합니다.
Future<ApiResponse> patchJsonWithAuth(
  String baseUrl,
  String path, {
  required Map<String, dynamic> body,
  Set<String> redactKeys = const {'password', 'currentPassword', 'newPassword'},
}) async {
  final token = await TokenStorage.getAccessToken();
  final api = ApiClient(baseUrl: baseUrl);
  final headers = token != null && token.isNotEmpty ? {'access': token} : null;

  ApiResponse response = await api.patchJson(
    path,
    headers: headers,
    body: body,
    redactKeys: redactKeys,
  );

  if (response.statusCode == 401) {
    final reissued = await reissueTokens(baseUrl);
    if (reissued) {
      final newToken = await TokenStorage.getAccessToken();
      if (newToken != null && newToken.isNotEmpty) {
        response = await api.patchJson(
          path,
          headers: {'access': newToken},
          body: body,
          redactKeys: redactKeys,
        );
      }
    }
  }

  return response;
}

/// access 토큰을 헤더에 넣어 POST 요청을 보냅니다.
/// 응답이 401이면 reissue를 시도하고, 성공 시 같은 요청을 새 토큰으로 한 번만 재시도합니다.
Future<ApiResponse> postJsonWithAuth(
  String baseUrl,
  String path, {
  required Map<String, dynamic> body,
  Set<String> redactKeys = const {'password'},
}) async {
  final token = await TokenStorage.getAccessToken();
  final api = ApiClient(baseUrl: baseUrl);
  final headers = token != null && token.isNotEmpty ? {'access': token} : null;

  ApiResponse response = await api.postJson(
    path,
    headers: headers,
    body: body,
    redactKeys: redactKeys,
  );

  if (response.statusCode == 401) {
    final reissued = await reissueTokens(baseUrl);
    if (reissued) {
      final newToken = await TokenStorage.getAccessToken();
      if (newToken != null && newToken.isNotEmpty) {
        response = await api.postJson(
          path,
          headers: {'access': newToken},
          body: body,
          redactKeys: redactKeys,
        );
      }
    }
  }

  return response;
}
