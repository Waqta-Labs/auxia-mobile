import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/citizen_report.dart';

/// Status of a citizen report as the backend knows it.
///
/// It has no Urgency Score: the public projection never exposes internal
/// prioritization variables (report 4, TS-C02), so the citizen only sees the
/// stage of the report.
final class RemoteReportStatus extends Equatable {
  const RemoteReportStatus({required this.status, this.etaMinutes});

  final CitizenReportStatus status;

  /// Minutes until the brigade arrives. The backend sends null while the
  /// brigades do not report their position.
  final int? etaMinutes;

  @override
  List<Object?> get props => [status, etaMinutes];
}

/// Port to the public citizen report endpoints of the backend.
///
/// * `POST /api/v1/public/field-reports`, idempotent by `clientReportId`
///   (201 the first time, 200 on a retry; 429 when the IP sent too many).
/// * `GET /api/v1/public/field-reports/{clientReportId}`, 404 when the backend
///   does not know the report.
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
