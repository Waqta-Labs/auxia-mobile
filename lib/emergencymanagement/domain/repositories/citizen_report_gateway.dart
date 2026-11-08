import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/citizen_report.dart';

/// Status of a citizen report as the backend knows it.
final class RemoteReportStatus extends Equatable {
  const RemoteReportStatus({required this.status, this.score, this.etaMinutes});

  final CitizenReportStatus status;

  /// Urgency Score of the zone, from 0 to 100, once prioritized.
  final double? score;

  /// Minutes until the brigade arrives (straight line from its base at
  /// 30 km/h, plan D1); null without coordinates.
  final int? etaMinutes;

  @override
  List<Object?> get props => [status, score, etaMinutes];
}

/// Port to the public citizen report endpoints of the backend.
///
/// * `POST /api/v1/public/field-reports`, idempotent by `clientReportId`
///   (201 the first time, 200 on a retry; 429 when the IP sent too many).
/// * `GET /api/v1/public/field-reports/{clientReportId}`, 404 when the backend
///   does not know the report.
/// * `PUT /api/v1/public/field-reports/{clientReportId}/attachments/{id}`,
///   the photo or the audio of the SOS, idempotent by attachment id.
abstract interface class CitizenReportGateway {
  /// Sends the SOS, or a follow-up detail when [relatedReport] is given.
  Future<Either<Failure, Unit>> submit(
    CitizenReport report, {
    String? clientReportId,
    String? text,
    CitizenReport? relatedReport,
  });

  Future<Either<Failure, RemoteReportStatus>> status(String clientReportId);

  /// Uploads an SOS of another phone that arrived by Mesh, as its origin
  /// built it, through [hops] phones this one included (plan D5).
  Future<Either<Failure, Unit>> submitRelayed(
    Map<String, Object?> body, {
    required int hops,
  });

  /// Uploads the file at [path] as an evidence of the SOS [clientReportId].
  Future<Either<Failure, Unit>> uploadEvidence(
    String clientReportId, {
    required String attachmentId,
    required String path,
  });
}
