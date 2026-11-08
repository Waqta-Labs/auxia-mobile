import 'package:dio/dio.dart';
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
/// does not know that report and is returned as is. A 404 on an evidence
/// means its SOS is not stored yet, so it is retried as well.
class HttpCitizenReportGateway implements CitizenReportGateway {
  HttpCitizenReportGateway(this._client, {this.readFile});

  static const String path = '/public/field-reports';

  final ApiClient _client;

  /// Builds the multipart file of an evidence (tests replace the disk).
  final Future<MultipartFile> Function(String path, DioMediaType type)?
  readFile;

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
  Future<Either<Failure, Unit>> submitRelayed(
    Map<String, Object?> body, {
    required int hops,
  }) async {
    final result = await _client.post(
      path,
      body: {
        ...body,
        'relay': {'hops': hops},
      },
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

  @override
  Future<Either<Failure, Unit>> uploadEvidence(
    String clientReportId, {
    required String attachmentId,
    required String path,
  }) async {
    final read =
        readFile ??
        (file, type) => MultipartFile.fromFile(file, contentType: type);
    final FormData form;
    try {
      form = FormData()
        ..files.add(MapEntry('file', await read(path, evidenceType(path))));
    } on Exception catch (error) {
      return Left(UnexpectedFailure('Evidence not readable: $error'));
    }
    final result = await _client.putMultipart(
      '${HttpCitizenReportGateway.path}/$clientReportId/attachments/'
      '$attachmentId',
      form: form,
      parse: (_) => unit,
    );
    return result.mapLeft(_channelNotReady);
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

/// Maps the status resource.
RemoteReportStatus remoteStatusFromJson(Map<String, Object?> json) =>
    RemoteReportStatus(
      status: switch (json['status']) {
        'PRIORITIZED' => CitizenReportStatus.prioritized,
        'BRIGADE_ON_THE_WAY' => CitizenReportStatus.brigadeOnTheWay,
        _ => CitizenReportStatus.received,
      },
      score: (json['score'] as num?)?.toDouble(),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
    );

/// Content type of an evidence file, from its extension. The backend reads
/// the type from the part, not from the file name.
DioMediaType evidenceType(String path) {
  final extension = path.toLowerCase().split('.').last;
  return switch (extension) {
    'm4a' || 'mp4' => DioMediaType('audio', 'mp4'),
    'aac' => DioMediaType('audio', 'aac'),
    'mp3' => DioMediaType('audio', 'mpeg'),
    'ogg' => DioMediaType('audio', 'ogg'),
    'wav' => DioMediaType('audio', 'wav'),
    'png' => DioMediaType('image', 'png'),
    'webp' => DioMediaType('image', 'webp'),
    'heic' => DioMediaType('image', 'heic'),
    _ => DioMediaType('image', 'jpeg'),
  };
}

/// The backend uses `LocalDateTime` in UTC without zone.
String _localDateTime(DateTime time) {
  final iso = time.toUtc().toIso8601String();
  return iso.substring(0, 19);
}
