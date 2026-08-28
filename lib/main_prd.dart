import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/vintly_app.dart';
import 'config/backend_prd.dart' as backend;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.instance = AppConfig(backend: backend.backendConfig);
  await initializeNaverMap();
  runApp(const VintlyApp());
}

