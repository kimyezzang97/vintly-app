enum AppEnv { local, dev, prd }

class BackendConfig {
  const BackendConfig({
    required this.env,
    required this.baseUrl,
    required this.naverMapClientId,
  });

  final AppEnv env;
  final String baseUrl;
  final String naverMapClientId;
}

