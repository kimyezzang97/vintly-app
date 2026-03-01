// =============================================================================
// 현재 로그인 사용자 (메모리 보관)
// =============================================================================
//
// GET /api/v1/members/me 응답으로 받은 사용자 정보를 앱 실행 중 메모리에만 보관합니다.
// - 앱 실행 시(토큰 있음): RootScreen에서 /me 호출 후 여기에 세팅
// - 로그인 성공 시: LoginScreen에서 /me 호출 후 여기에 세팅
// - 로그아웃 시: CurrentUserHolder.clear() 호출
//
// Storage에 쓰지 않으므로 앱을 종료하면 사라집니다.
// =============================================================================

import '../api/authenticated_api.dart';
import 'token_storage.dart';

/// /api/v1/members/me 의 data 필드 한 건
class CurrentUser {
  const CurrentUser({
    required this.memberId,
    required this.nickname,
    required this.email,
    required this.role,
  });

  final int memberId;
  final String nickname;
  final String email;
  final String role;

  static CurrentUser? fromMeData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final mid = data['memberId'];
    final id = mid is int ? mid : (mid != null ? int.tryParse(mid.toString()) : null);
    if (id == null) return null;
    return CurrentUser(
      memberId: id,
      nickname: data['nickname']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      role: data['role']?.toString() ?? '',
    );
  }
}

/// 현재 로그인한 사용자를 메모리에서만 보관하는 홀더
class CurrentUserHolder {
  CurrentUserHolder._();

  static CurrentUser? _instance;

  static CurrentUser? get instance => _instance;

  static int? get memberId => _instance?.memberId;
  static String? get nickname => _instance?.nickname;
  static String? get email => _instance?.email;
  static String? get role => _instance?.role;

  /// /me 응답의 data로 세팅 (메모리에만 저장)
  static void setFromMeData(Map<String, dynamic>? data) {
    _instance = CurrentUser.fromMeData(data);
  }

  /// 로그아웃 시 호출. 메모리에서만 제거 (Storage는 건드리지 않음)
  static void clear() {
    _instance = null;
  }
}

/// GET /api/v1/members/me 를 호출해 응답을 CurrentUserHolder에 세팅합니다.
/// - 성공 시 true 반환
/// - 401/403 시 토큰 삭제 + Holder clear 후 false 반환 (호출측에서 로그인 화면으로 이동)
Future<bool> fetchAndSetCurrentUser(String baseUrl) async {
  const path = '/api/v1/members/me';
  final response = await getJsonWithAuth(baseUrl, path);

  final code = response.code ?? response.statusCode;

  if (response.statusCode == 401 || code == 401 || response.statusCode == 403) {
    await TokenStorage.clearAll();
    CurrentUserHolder.clear();
    return false;
  }

  final success = response.json['success'] == true;
  final data = response.json['data'];

  if (!success || data is! Map<String, dynamic>) {
    CurrentUserHolder.clear();
    return false;
  }

  CurrentUserHolder.setFromMeData(data);
  return true;
}
