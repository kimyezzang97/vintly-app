import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈(임시)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.login,
              (route) => false,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: const Center(
        child: Text('다음 단계: 빈티지 샵/게시글 기능을 붙이면 됩니다.'),
      ),
    );
  }
}

