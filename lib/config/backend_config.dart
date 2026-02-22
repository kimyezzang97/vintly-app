enum AppEnv { local, dev, prd }

class BackendConfig {
  const BackendConfig({
    required this.env,
    required this.baseUrl,
  });

  final AppEnv env;
  final String baseUrl;
}

