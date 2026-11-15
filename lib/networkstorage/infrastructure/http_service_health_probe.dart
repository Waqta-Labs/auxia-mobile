import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../application/service_status.dart';

/// [ServiceHealthProbe] over the public health endpoints: Spring Boot
/// Actuator in the backend and `/health` in the AI Service.
class HttpServiceHealthProbe implements ServiceHealthProbe {
  HttpServiceHealthProbe(this._config, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = _config.connectTimeout
      ..receiveTimeout = _config.receiveTimeout;
  }

  final AppConfig _config;
  final Dio _dio;

  @override
  Future<bool> isUp(CloudService service) async {
    final url = switch (service) {
      CloudService.backend => '${_config.apiBaseUrl}/actuator/health',
      CloudService.aiService => '${_config.aiServiceUrl}/health',
    };
    try {
      final data = (await _dio.get<Object?>(url)).data;
      return switch (service) {
        // Actuator answers 200 with {"status": "UP"} when every check passes.
        CloudService.backend =>
          data is Map<String, Object?> && data['status'] == 'UP',
        CloudService.aiService => true,
      };
    } on DioException {
      // No answer or an error status: the service is down for the app.
      return false;
    }
  }
}
