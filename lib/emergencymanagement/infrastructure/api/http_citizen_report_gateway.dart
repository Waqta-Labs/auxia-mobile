import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../../../core/network/api_client.dart';
import '../../domain/model/citizen_report.dart';
import '../../domain/repositories/citizen_report_gateway.dart';

/// [CitizenReportGateway] over the public field report endpoints.
///
/// A 404 on the POST means the backend in use does not publish the endpoint.
/// It is turned into a retryable failure so the report stays queued on the
/// device instead of being discarded. A 404 on the status means the backend
/// does not know that report and is returned as is.
class HttpCitizenReportGateway implements CitizenReportGateway {
  HttpCitizenReportGateway(this._client);

  static const String path = '/public/field-reports';

  final ApiClient _client;

  @override
  Future<Either<Failure, Unit>> submit(
    CitizenReport report, {
    String? clientReportId,
    String? text,
    CitizenReport? relatedReport,
  }) async {
    final result = await _client.post(
      path,
      body: citizenReportBody(
        report,
        clientReportId: clientReportId,
        text: text,
        relatedReport: relatedReport,
      ),
      parse: (_) => unit,
    );
    return result.mapLeft(_channelNotReady);
  }

  @override
  Future<Either<Failure, RemoteReportStatus>> status(
    String clientReportId,
  ) async {
    final result = await _client.get(
      '$path/$clientReportId',
      parse: (data) => remoteStatusFromJson(data! as Map<String, Object?>),
    );
    return result;
  }

  static Failure _channelNotReady(Failure failure) => failure is NotFoundFailure
      ? ServerFailure(failure.message, statusCode: 404)
      : failure;
}

/// Request body of `POST /public/field-reports`.
Map<String, Object?> citizenReportBody(
  CitizenReport report, {
  String? clientReportId,
  String? text,
  CitizenReport? relatedReport,
}) => {
  'clientReportId': clientReportId ?? report.id,
  'source': 'CITIZEN',
  'category': report.category.code,
  'text': text ?? report.toReportText(),
  'reportedAt': _localDateTime(report.reportedAt),
  'location': ?report.location?.toJson(),
  'people': {
    'children': report.detail.children,
    'elderly': report.detail.elderly,
    'injured': report.detail.injured,
  },
  'accessConditions': [
    for (final condition in AccessCondition.values)
      if (report.detail.accessConditions.contains(condition)) condition.code,
  ],
  'relatedReportId': ?relatedReport?.id,
};

/// Maps the status resource. A `score` in the body is ignored on purpose.
RemoteReportStatus remoteStatusFromJson(Map<String, Object?> json) =>
    RemoteReportStatus(
      status: switch (json['status']) {
        'PRIORITIZED' => CitizenReportStatus.prioritized,
        'BRIGADE_ON_THE_WAY' => CitizenReportStatus.brigadeOnTheWay,
        _ => CitizenReportStatus.received,
      },
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
    );

/// The backend uses `LocalDateTime` in UTC without zone.
String _localDateTime(DateTime time) {
  final iso = time.toUtc().toIso8601String();
  return iso.substring(0, 19);
}
