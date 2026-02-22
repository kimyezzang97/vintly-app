abstract class AppRoutes {
  /// 앱 최초 진입 시 토큰 확인 후 /home 또는 /login 으로 이동하는 화면
  static const root = '/';
  static const login = '/login';
  static const signUp = '/sign-up';
  /// 빈티지 샵 목록 화면 (로그인 후 메인)
  static const home = '/home';
}

