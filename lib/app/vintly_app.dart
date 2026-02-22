import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'root_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/vintage/presentation/vintage_list_screen.dart';

class VintlyApp extends StatelessWidget {
  const VintlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vintly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E342E), // 브라운 톤
          primary: const Color(0xFF4E342E),
          secondary: const Color(0xFF2E7D32), // 그린 톤
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      // 앱 시작 시 루트 화면 → 토큰 있으면 /home(빈티지 목록), 없으면 /login
      initialRoute: AppRoutes.root,
      routes: {
        AppRoutes.root: (_) => const RootScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.signUp: (_) => const SignUpScreen(),
        AppRoutes.home: (_) => const VintageListScreen(),
      },
    );
  }
}

