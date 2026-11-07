import 'dart:convert';

import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/domain/repositories/citizen_report_gateway.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/api/http_citizen_report_gateway.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final _report = CitizenReport(
  id: 'c0ffee00-0000-4000-8000-000000000412',
  code: 'SR-0412',
  category: HelpCategory.medical,
  reportedAt: DateTime.utc(2026, 11, 6, 14, 41, 5),
  status: CitizenReportStatus.saved,
  location: const GeoPoint(-12.0464, -77.0428),
  detail: const EmergencyDetail(
    children: 3,
    injured: 2,
    accessConditions: {
      AccessCondition.noDrinkingWater,
      AccessCondition.roadBlocked,
    },
  ),
);

void main() {
  test('sends the SOS as the proposed public field report', () async {
    final adapter = FakeHttpAdapter({
      'POST /api/v1/public/field-reports': (201, {'id': 'x'}),
    });

    final result = await HttpCitizenReportGateway(
      fakeApiClient(adapter),
    ).submit(_report);

    expect(result.isRight(), isTrue);
    final request = adapter.requests.single;
    expect(request.headers.containsKey('Authorization'), isFalse);
    final body = jsonDecode(jsonEncode(request.data)) as Map<String, Object?>;
    expect(body, {
      'clientReportId': 'c0ffee00-0000-4000-8000-000000000412',
      'source': 'CITIZEN',
      'category': 'MEDICAL',
      'text':
          'SOS Médico. Necesitan ayuda 3 niños y 2 heridos. '
          'Vía bloqueada y sin agua potable. '
          'Ubicación GPS -12.0464, -77.0428.',
      'reportedAt': '2026-11-06T14:41:05',
      'location': {'latitude': -12.0464, 'longitude': -77.0428},
      'people': {'children': 3, 'elderly': 0, 'injured': 2},
      'accessConditions': ['ROAD_BLOCKED', 'NO_DRINKING_WATER'],
    });
  });

  test('a follow-up names the first report', () {
    final body = citizenReportBody(
      _report,
      clientReportId: 'follow-up-1',
      text: 'Detalle adicional',
      relatedReport: _report,
    );

    expect(body['clientReportId'], 'follow-up-1');
    expect(body['relatedReportId'], _report.id);
    expect(body['text'], 'Detalle adicional');
  });

  test('a missing endpoint keeps the report queued', () async {
    final adapter = FakeHttpAdapter({});

    final result = await HttpCitizenReportGateway(
      fakeApiClient(adapter),
    ).submit(_report);

    final failure = result.getLeft().toNullable()!;
    expect(failure, isA<ServerFailure>());
    expect(failure.statusCode, 404);
    expect(failure.isRetryable, isTrue);
  });

  test('reads the status and the eta, never the score', () async {
    final adapter = FakeHttpAdapter({
      'GET /api/v1/public/field-reports/${_report.id}': (
        200,
        {'status': 'BRIGADE_ON_THE_WAY', 'score': 94.2, 'etaMinutes': 12},
      ),
    });

    final result = await HttpCitizenReportGateway(
      fakeApiClient(adapter),
    ).status(_report.id);

    final status = result.getRight().toNullable()!;
    expect(status.status, CitizenReportStatus.brigadeOnTheWay);
    expect(status.etaMinutes, 12);
    expect(status.props, isNot(contains(94.2)));
  });

  test('the backend sends score and eta as null', () {
    expect(
      remoteStatusFromJson({
        'status': 'PRIORITIZED',
        'score': null,
        'etaMinutes': null,
      }),
      const RemoteReportStatus(status: CitizenReportStatus.prioritized),
    );
  });

  test('an unknown report is a not found, not a retry', () async {
    final adapter = FakeHttpAdapter({
      'GET /api/v1/public/field-reports/${_report.id}': (
        404,
        {'detail': 'Not found'},
      ),
    });

    final result = await HttpCitizenReportGateway(
      fakeApiClient(adapter),
    ).status(_report.id);

    expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
  });

  test('an unknown status is read as received', () {
    expect(
      remoteStatusFromJson({'status': 'RECEIVED'}).status,
      CitizenReportStatus.received,
    );
    expect(
      remoteStatusFromJson({'status': 'PRIORITIZED', 'score': 81}).status,
      CitizenReportStatus.prioritized,
    );
  });
}
