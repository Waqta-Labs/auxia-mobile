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
    this.apiPrefix = '/api/v1',
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
    this.mapTileUrlTemplate = defaultMapTileUrlTemplate,
  });

  /// Configuration read from `--dart-define`, with the Azure backend of the
  /// report as default.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    ),
  );

  static const String defaultApiBaseUrl =
      'https://auxia-backend.azurewebsites.net';

  /// Dark raster tiles of CARTO over OpenStreetMap data, close to the dark
  /// map of the A_07 mockup. Attribution is shown on the map.
  static const String defaultMapTileUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  final String apiBaseUrl;
  final String apiPrefix;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Raster tiles of the maps; null hides the tiles.
  final String? mapTileUrlTemplate;

  /// Base URL of the REST API, with its version prefix.
  String get apiUrl => '$apiBaseUrl$apiPrefix';
}
