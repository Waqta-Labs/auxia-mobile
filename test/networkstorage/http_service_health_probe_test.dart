import 'package:auxia_mobile/core/config/app_config.dart';
import 'package:auxia_mobile/networkstorage/application/service_status.dart';
import 'package:auxia_mobile/networkstorage/infrastructure/http_service_health_probe.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  const config = AppConfig(
    apiBaseUrl: 'https://backend.test',
    aiServiceUrl: 'https://ai.test',
  );

  HttpServiceHealthProbe probe(FakeHttpAdapter adapter) =>
      HttpServiceHealthProbe(config, dio: Dio()..httpClientAdapter = adapter);

  test('the backend is up when Actuator answers UP', () async {
    final adapter = FakeHttpAdapter({
      'GET /actuator/health': (200, {'status': 'UP'}),
    });

    expect(await probe(adapter).isUp(CloudService.backend), isTrue);
    expect(adapter.requests.single.uri.host, 'backend.test');
  });

  test('the backend is down when Actuator answers DOWN', () async {
    final adapter = FakeHttpAdapter({
      'GET /actuator/health': (503, {'status': 'DOWN'}),
    });

    expect(await probe(adapter).isUp(CloudService.backend), isFalse);
  });

  test('the AI Service is up when its health check answers', () async {
    final adapter = FakeHttpAdapter({
      'GET /health': (200, {'status': 'ok'}),
    });

    expect(await probe(adapter).isUp(CloudService.aiService), isTrue);
    expect(adapter.requests.single.uri.host, 'ai.test');
  });

  test('a service without answer is down', () async {
    final adapter = FakeHttpAdapter(const {});

    expect(await probe(adapter).isUp(CloudService.aiService), isFalse);
  });
}
