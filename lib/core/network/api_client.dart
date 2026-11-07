import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../config/app_config.dart';
import '../failure.dart';
import 'problem_details.dart';

/// Returns the bearer token of the current session, or null without session.
typedef AccessTokenProvider = Future<String?> Function();

/// Returns the language tag sent in `Accept-Language` (for example `es`).
typedef LanguageProvider = String Function();

/// Thin wrapper over [Dio] for the AuxIA REST API.
///
/// Every call returns `Either<Failure, T>`: gateways never see a
/// [DioException], and the UI never sees HTTP details.
class ApiClient {
  ApiClient({
    required AppConfig config,
    required AccessTokenProvider accessToken,
    required LanguageProvider language,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = config.apiUrl
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..headers['Accept'] = 'application/json, application/problem+json';
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['Accept-Language'] = language();
          final token = await accessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Future<Either<Failure, T>> get<T>(
    String path, {
    Map<String, Object?>? query,
    required T Function(Object? data) parse,
  }) => _send(
    () => _dio.get<Object?>(path, queryParameters: _clean(query)),
    parse,
  );

  Future<Either<Failure, T>> post<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parse,
  }) => _send(() => _dio.post<Object?>(path, data: body), parse);

  Future<Either<Failure, T>> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? data) parse,
  }) => _send(() => _dio.patch<Object?>(path, data: body), parse);

  /// Sends a `multipart/form-data` request (delivery registration).
  Future<Either<Failure, T>> postMultipart<T>(
    String path, {
    required FormData form,
    required T Function(Object? data) parse,
  }) => _send(() => _dio.post<Object?>(path, data: form), parse);

  Future<Either<Failure, T>> _send<T>(
    Future<Response<Object?>> Function() request,
    T Function(Object? data) parse,
  ) async {
    try {
      final response = await request();
      return Right(parse(response.data));
    } on DioException catch (error) {
      return Left(_toFailure(error));
    } on FormatException catch (error) {
      return Left(UnexpectedFailure(error.message));
    } on TypeError catch (error) {
      return Left(UnexpectedFailure(error.toString()));
    }
  }

  static Map<String, Object?>? _clean(Map<String, Object?>? query) {
    if (query == null) return null;
    return {
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  static Failure _toFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure(error.message ?? '');
      case DioExceptionType.transformTimeout:
        return UnexpectedFailure(error.message ?? '');
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return error.error is Exception && error.response == null
            ? NetworkFailure(error.message ?? '')
            : UnexpectedFailure(error.message ?? '');
      case DioExceptionType.badResponse:
        final response = error.response;
        final status = response?.statusCode ?? 0;
        final problem = ProblemDetails.tryParse(response?.data);
        final message = problem?.detail ?? problem?.title ?? '';
        return switch (status) {
          401 => UnauthorizedFailure(message),
          403 => ForbiddenFailure(message),
          404 => NotFoundFailure(message),
          400 || 409 || 415 || 422 => ValidationFailure(
            message,
            statusCode: status,
            fieldErrors: problem?.fieldErrors ?? const {},
          ),
          // A rate limit (429) is temporary, like a server error: the queued
          // write must wait and retry, never be discarded.
          429 || >= 500 => ServerFailure(message, statusCode: status),
          _ => UnexpectedFailure(message),
        };
    }
  }
}
