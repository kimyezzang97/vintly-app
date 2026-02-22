// =============================================================================
// 토큰 저장소 (Token Storage)
// =============================================================================
//
// 로그인 후 서버에서 받은 access 토큰, refresh 토큰을 기기에 안전하게 보관합니다.
// Flutter에서는 보안이 필요한 값(비밀번호, 토큰 등)을 저장할 때
// SharedPreferences 대신 flutter_secure_storage를 사용하는 것이 권장됩니다.
//
// - Android: KeyStore (암호화된 저장소) 사용
// - iOS: Keychain (시스템 키체인) 사용
//
// 사용 예:
//   await TokenStorage.saveTokens(access: 'xxx', refresh: 'yyy');
//   final access = await TokenStorage.getAccessToken();
//   await TokenStorage.clearAll();
// =============================================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// access / refresh 토큰을 secure storage에 저장·조회·삭제하는 정적 메서드 모음
class TokenStorage {
  TokenStorage._();

  // ---------------------------------------------------------------------------
  // 저장 시 사용할 키 이름. 서버에서 쓰는 이름(access, refresh)과 맞춰두었습니다.
  // 나중에 다른 키가 필요하면 여기 상수만 추가하면 됩니다.
  // ---------------------------------------------------------------------------
  static const String _keyAccess = 'access';
  static const String _keyRefresh = 'refresh';
  static const String _keyLastEmail = 'last_login_email';

  // ---------------------------------------------------------------------------
  // FlutterSecureStorage 인스턴스
  // - 보관 기간: 앱에서 만료를 두지 않음. 앱 삭제 또는 clearAll() 전까지 유지.
  // - Android: 에뮬레이터 재부팅 시 일부 환경에서 KeyStore 준비 전 읽기 오류가 나면
  //   resetOnError: true(기본)일 때 저장소가 비워질 수 있음. false로 두어 오류 시에도
  //   데이터를 지우지 않고 유지하도록 함 (실기기/에뮬 모두 재시작 후 로그인 유지에 유리).
  // - iOS: 기본값 사용.
  // ---------------------------------------------------------------------------
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
  );

  /// access 토큰과 refresh 토큰을 한 번에 저장합니다.
  /// 로그인 성공 직후 이 메서드를 호출하면 됩니다.
  ///
  /// [access] access 토큰 (응답 헤더에서 받은 값). null이면 기존 값을 지우지 않고 유지합니다.
  /// [refresh] refresh 토큰 (Set-Cookie에서 받은 값). null이면 기존 값을 지우지 않고 유지합니다.
  static Future<void> saveTokens({
    String? access,
    String? refresh,
  }) async {
    if (access != null) {
      await _storage.write(key: _keyAccess, value: access);
    }
    if (refresh != null) {
      await _storage.write(key: _keyRefresh, value: refresh);
    }
  }

  /// 저장된 access 토큰을 읽어옵니다.
  /// 없으면 null을 반환합니다.
  /// API 호출 시 access 헤더에 이 값을 그대로 붙일 때 사용합니다.
  static Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccess);
  }

  /// 저장된 refresh 토큰을 읽어옵니다.
  /// 없으면 null을 반환합니다.
  /// access 토큰 만료 시 서버에 새 access를 발급받을 때 사용합니다.
  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefresh);
  }

  /// access, refresh 토큰을 모두 삭제합니다.
  /// 로그아웃 시 호출하면 됩니다. (마지막 로그인 이메일은 유지됩니다.)
  static Future<void> clearAll() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
  }

  /// 마지막으로 로그인에 성공한 이메일을 저장합니다.
  /// 로그인 성공 시 호출하면 됩니다.
  static Future<void> saveLastLoginEmail(String email) async {
    if (email.trim().isEmpty) return;
    await _storage.write(key: _keyLastEmail, value: email.trim());
  }

  /// 저장된 마지막 로그인 이메일을 읽어옵니다.
  /// 없으면 null을 반환합니다. 로그인 화면에서 이메일 필드 기본값으로 쓸 수 있습니다.
  static Future<String?> getLastLoginEmail() async {
    return _storage.read(key: _keyLastEmail);
  }

  /// 현재 로그인된 상태인지 여부를 판단할 때 쓸 수 있습니다.
  /// access 토큰이 하나라도 있으면 true, 없으면 false입니다.
  static Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.trim().isNotEmpty;
  }
}
