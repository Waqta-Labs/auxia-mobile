import 'dart:convert';
import 'dart:typed_data';

import 'package:auxia_mobile/core/config/app_config.dart';
import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a fixed status and JSON body, and records the
/// last request so its headers can be checked.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.status = 200, this.body, this.error});

  final int status;
  final Object? body;
  final DioExceptionType? error;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (error != null) {
      throw DioException(requestOptions: options, type: error!);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_FakeAdapter adapter, {String? token}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    config: const AppConfig(apiBaseUrl: 'https://api.test'),
    accessToken: () async => token,
    language: () => 'es',
    dio: dio,
  );
}

void main() {
  test('parses a successful response', () async {
    final adapter = _FakeAdapter(body: {'name': 'Chosica'});

    final result = await _client(
      adapter,
    ).get('/zones/1', parse: (data) => (data! as Map)['name'] as String);

    expect(result.getRight().toNullable(), 'Chosica');
    expect(
      adapter.lastRequest!.uri.toString(),
      'https://api.test/api/v1/zones/1',
    );
  });

  test('sends the bearer token and the language', () async {
    final adapter = _FakeAdapter(body: const <String, Object?>{});

    await _client(adapter, token: 'abc').get('/users/me', parse: (_) => null);

    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer abc');
    expect(adapter.lastRequest!.headers['Accept-Language'], 'es');
  });

  test('omits the authorization header without session', () async {
    final adapter = _FakeAdapter(body: const <String, Object?>{});

    await _client(adapter).get('/public/emergencies', parse: (_) => null);

    expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
  });

  test('drops null query parameters', () async {
    final adapter = _FakeAdapter(body: const <Object?>[]);

    await _client(adapter).get(
      '/brigades',
      query: {'status': 'ASSIGNED', 'zoneId': null},
      parse: (_) => null,
    );

    expect(adapter.lastRequest!.queryParameters, {'status': 'ASSIGNED'});
  });

  test('maps a validation problem to a validation failure', () async {
    final adapter = _FakeAdapter(
      status: 400,
      body: {
        'title': 'Bad Request',
        'status': 400,
        'detail': 'La cantidad supera la del plan.',
        'errors': [
          {'field': 'items[0].quantity', 'message': 'must be at most 50'},
        ],
      },
    );

    final result = await _client(adapter).post('/x', parse: (_) => null);
    final failure = result.getLeft().toNullable();

    expect(failure, isA<ValidationFailure>());
    expect(failure!.message, 'La cantidad supera la del plan.');
    expect((failure as ValidationFailure).fieldErrors, {
      'items[0].quantity': 'must be at most 50',
    });
    expect(failure.isRetryable, isFalse);
  });

  test('maps 401 to an unauthorized failure', () async {
    final adapter = _FakeAdapter(status: 401, body: {'detail': 'Expired'});

    final result = await _client(adapter).get('/users/me', parse: (_) => null);

    expect(result.getLeft().toNullable(), const UnauthorizedFailure('Expired'));
  });

  test('maps server errors to retryable failures', () async {
    final adapter = _FakeAdapter(status: 503, body: {'detail': 'Down'});

    final result = await _client(adapter).get('/x', parse: (_) => null);
    final failure = result.getLeft().toNullable()!;

    expect(failure, isA<ServerFailure>());
    expect(failure.isRetryable, isTrue);
  });

  test('a rate limit keeps the write queued for a retry', () async {
    final adapter = _FakeAdapter(status: 429, body: {'detail': 'Too many'});

    final result = await _client(adapter).post('/x', parse: (_) => null);
    final failure = result.getLeft().toNullable()!;

    expect(failure, const ServerFailure('Too many', statusCode: 429));
    expect(failure.isRetryable, isTrue);
  });

  test('maps a connection error to a network failure', () async {
    final adapter = _FakeAdapter(error: DioExceptionType.connectionError);

    final result = await _client(adapter).get('/x', parse: (_) => null);

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });

  test('maps an unexpected payload to an unexpected failure', () async {
    final adapter = _FakeAdapter(body: const <Object?>[]);

    final result = await _client(
      adapter,
    ).get('/x', parse: (data) => (data! as Map)['id'] as String);

    expect(result.getLeft().toNullable(), isA<UnexpectedFailure>());
  });
}
