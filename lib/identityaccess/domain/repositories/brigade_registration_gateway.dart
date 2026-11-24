import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/brigade_credential.dart';

/// What the administrator decided about a credential.
final class RegistrationDecision extends Equatable {
  const RegistrationDecision(this.status, {this.reason});

  final CredentialStatus status;

  /// Why it was rejected.
  final String? reason;

  @override
  List<Object?> get props => [status, reason];
}

/// Port to the public brigade registration endpoints (plan, iteration 3).
abstract interface class BrigadeRegistrationGateway {
  /// Sends the credential with the name and phone of A_01; idempotent by
  /// its registration id.
  Future<Either<Failure, Unit>> submit(
    BrigadeCredential credential, {
    required String fullName,
    required String phone,
  });

  /// Asks for the decision, proving the device with its secret.
  Future<Either<Failure, RegistrationDecision>> status(
    BrigadeCredential credential,
  );
}
