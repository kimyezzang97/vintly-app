// =============================================================================
// 토큰 재발급 (Token Reissue)
// =============================================================================
//
// access 토큰이 만료되면 refresh 토큰으로 POST /api/v1/auth/reissue 를 호출해서
// 새 access·refresh를 받고, TokenStorage에 다시 저장합니다.
//
// 요청: POST /api/v1/auth/reissue, Cookie 헤더에 refresh=<refresh_token>
// 응답: 로그인과 동일 — access는 헤더, refresh는 Set-Cookie
// =============================================================================

import '../api/api_client.dart';
import 'token_storage.dart';

/// Set-Cookie 헤더 값들에서 쿠키 이름에 해당하는 값만 추출
String? _extractCookie(List<String> setCookieHeaders, String name) {
  for (final cookie in setCookieHeaders) {
    final parts = cookie.split(';');
    if (parts.isEmpty) continue;
    final kv = parts.first.split('=');
    if (kv.length < 2) continue;
    final key = kv[0].trim();
    if (key == name) {
      return kv.sublist(1).join('=').trim();
    }
  }
  return null;
}

/// access 토큰이 만료됐을 때 refresh 토큰으로 재발급 요청 후 새 토큰을 저장합니다.
/// 성공하면 true, 실패(refresh 없음/만료/네트워크 오류 등)하면 false.
Future<bool> reissueTokens(String baseUrl) async {
  final refreshToken = await TokenStorage.getRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) {
    return false;
  }

  try {
    final api = ApiClient(baseUrl: baseUrl);
    final response = await api.postJson(
      '/api/v1/auth/reissue',
      body: <String, dynamic>{},
      headers: {'Cookie': 'refresh=$refreshToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    // access: 헤더에서
    String? accessToken;
    for (final v in response.header('access')) {
      final s = v.trim();
      if (s.isNotEmpty) {
        accessToken = s;
        break;
      }
    }

    // refresh: Set-Cookie에서
    final cookies = response.header('set-cookie');
    final newRefresh = _extractCookie(cookies, 'refresh');

    await TokenStorage.saveTokens(
      access: accessToken,
      refresh: newRefresh ?? refreshToken,
    );
    return true;
  } catch (_) {
    return false;
  }
}
