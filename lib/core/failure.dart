import 'package:equatable/equatable.dart';

/// Error returned by a use case instead of throwing.
///
/// The subtypes tell the UI what to do: keep the data queued (no connection),
/// ask for a new sign-in (unauthorized) or show the server message.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.statusCode});

  /// Human readable message. For API errors it is the `detail` of the
  /// problem+json body, already translated by the backend.
  final String message;
  final int? statusCode;

  @override
  List<Object?> get props => [runtimeType, message, statusCode];
}

/// The device has no connection or the server did not answer in time. The
/// operation can be retried later.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = '']);
}

/// The session is missing or expired (HTTP 401).
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = '']) : super(statusCode: 401);
}

/// The user is signed in but the role does not allow the action (HTTP 403).
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = '']) : super(statusCode: 403);
}

/// The resource or the endpoint does not exist (HTTP 404).
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = '']) : super(statusCode: 404);
}

/// The request was rejected by a business or validation rule (HTTP 400, 409,
/// 415 or 422). Retrying the same request will fail again.
final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.statusCode,
    this.fieldErrors = const {},
  });

  /// Messages per field, from the `errors` array of the problem+json body.
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// The server failed (HTTP 5xx). The operation can be retried later.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

/// Any other error, including local storage and device errors.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}

extension FailureRetry on Failure {
  /// Whether an outbox item that failed with this error should be retried.
  bool get isRetryable => switch (this) {
    NetworkFailure() || ServerFailure() || UnauthorizedFailure() => true,
    _ => false,
  };
}
