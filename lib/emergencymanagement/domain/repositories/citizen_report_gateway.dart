import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/citizen_report.dart';

/// Status of a citizen report as the backend knows it.
final class RemoteReportStatus extends Equatable {
  const RemoteReportStatus({required this.status, this.score, this.etaMinutes});

  final CitizenReportStatus status;
  final double? score;
  final int? etaMinutes;

  @override
  List<Object?> get props => [status, score, etaMinutes];
}

/// Port to the public citizen report endpoints of the backend.
///
/// The backend does not have them yet; the contract proposed in the project
/// guide is:
///
/// * `POST /api/v1/public/field-reports`, idempotent by `clientReportId`.
/// * `GET /api/v1/public/field-reports/{clientReportId}`.
abstract interface class CitizenReportGateway {
  /// Sends the SOS, or a follow-up detail when [relatedReport] is given.
  Future<Either<Failure, Unit>> submit(
    CitizenReport report, {
    String? clientReportId,
    String? text,
    CitizenReport? relatedReport,
  });

  Future<Either<Failure, RemoteReportStatus>> status(String clientReportId);
}
