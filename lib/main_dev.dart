import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/vintly_app.dart';
import 'config/backend_dev.dart' as backend;

void main() {
  AppConfig.instance = AppConfig(backend: backend.backendConfig);
  runApp(const VintlyApp());
}

