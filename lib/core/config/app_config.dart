/// Build-time configuration of the app.
///
/// The backend URL can be changed without touching the code:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
/// ```
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.aiServiceUrl = defaultAiServiceUrl,
    this.apiPrefix = '/api/v1',
    this.connectTimeout = const Duration(seconds: 15),
    // A verification rereads the evidence from storage: on the Azure backend
    // it took 18 s and 28 s, so 30 s left almost no margin.
    this.receiveTimeout = const Duration(seconds: 45),
  });

  /// Configuration read from `--dart-define`, with the Azure backend of the
  /// report as default.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    ),
    aiServiceUrl: String.fromEnvironment(
      'AI_SERVICE_URL',
      defaultValue: defaultAiServiceUrl,
    ),
  );

  static const String defaultApiBaseUrl =
      'https://auxia-backend.azurewebsites.net';

  static const String defaultAiServiceUrl =
      'https://auxia-ai-service.azurewebsites.net';

  final String apiBaseUrl;

  /// AI Service, only for its public health check: its key belongs to the
  /// backend and never reaches the device.
  final String aiServiceUrl;
  final String apiPrefix;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Base URL of the REST API, with its version prefix.
  String get apiUrl => '$apiBaseUrl$apiPrefix';
}
