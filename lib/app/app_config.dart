import '../config/backend_config.dart';

class AppConfig {
  const AppConfig({
    required this.backend,
  });

  final BackendConfig backend;

  static late AppConfig instance;
}

