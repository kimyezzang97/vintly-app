import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/vintly_app.dart';
import 'config/backend_dev.dart' as backend;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 기본 엔트리포인트는 dev로 둡니다.
  // 필요 시 실행 타겟을 바꿔서 사용하세요:
  // - lib/main_local.dart
  // - lib/main_dev.dart
  // - lib/main_prd.dart
  AppConfig.instance = AppConfig(backend: backend.backendConfig);
  await initializeNaverMap();
  runApp(const VintlyApp());
}
