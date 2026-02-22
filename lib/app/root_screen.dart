// =============================================================================
// 루트 화면 (Root Screen)
// =============================================================================
//
// 앱이 처음 실행될 때 이 화면이 표시됩니다.
// 저장된 access 토큰이 있는지 확인한 뒤:
//   - 있으면 → 빈티지 샵 목록 화면(/home)으로 이동
//   - 없으면 → 로그인 화면(/login)으로 이동
//
// 이렇게 하면 이미 로그인한 사용자는 앱을 켜자마자 목록 화면으로 갑니다.
// =============================================================================

import 'package:flutter/material.dart';

import 'app_routes.dart';
import '../shared/auth/token_storage.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 프레임이 그려진 뒤에 토큰 확인 후 라우팅합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndNavigate());
  }

  Future<void> _checkAndNavigate() async {
    final hasToken = await TokenStorage.hasAccessToken();
    if (!mounted) return;

    final route = hasToken ? AppRoutes.home : AppRoutes.login;
    // pushReplacementNamed 로 이 화면을 스택에서 제거하고 목적지로 교체합니다.
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    // 라우팅이 끝날 때까지 잠깐 보이는 화면 (스플래시처럼)
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Vintly'),
          ],
        ),
      ),
    );
  }
}
