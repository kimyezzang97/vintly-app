import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../config/backend_config.dart';

class AppConfig {
  const AppConfig({
    required this.backend,
  });

  final BackendConfig backend;

  static late AppConfig instance;
}

Future<void> initializeNaverMap() async {
  final clientId = AppConfig.instance.backend.naverMapClientId.trim();
  if (clientId.isEmpty) {
    throw StateError('네이버 지도 Client ID가 설정되지 않았습니다.');
  }

  await FlutterNaverMap().init(
    clientId: clientId,
    onAuthFailed: (exception) {
      debugPrint('[NaverMap] authentication failed: $exception');
    },
  );
}

