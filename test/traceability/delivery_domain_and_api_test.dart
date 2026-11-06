import 'dart:convert';

import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:auxia_mobile/traceability/domain/model/delivery.dart';
import 'package:auxia_mobile/traceability/infrastructure/api/http_delivery_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

final _record = DeliveryRecord(
  order: sampleOrder,
  deliveredAt: DateTime.utc(2026, 11, 2, 10, 30),
  signaturePath: '/d/signature.png',
  photoPath: '/d/reception.jpg',
  status: DeliveryRecordStatus.queued,
  location: const GeoPoint(-11.9436, -76.7078),
);

Future<MultipartFile> _fakeFile(String path, DioMediaType type) async =>
    MultipartFile.fromBytes([1, 2, 3], filename: path, contentType: type);

void main() {
  group('package QR', () {
    test('accepts the delivery id', () {
      expect(
        deliveryIdFromQr(' 3F2A91C0-0000-4000-8000-000000002041 '),
        sampleOrder.deliveryId,
      );
    });

    test('accepts the verification url', () {
      expect(
        deliveryIdFromQr(
          'https://auxia-backend.azurewebsites.net/api/v1/deliveries/'
          '3f2a91c0-0000-4000-8000-000000002041/verify',
        ),
        sampleOrder.deliveryId,
      );
    });

    test('ignores anything else', () {
      expect(deliveryIdFromQr('https://example.com'), isNull);
    });

    test('shows a short code that can be read aloud', () {
      expect(sampleOrder.shortCode, '#3F2A-91C0');
    });
  });

  test('a line never goes above the plan nor below zero', () {
    final line = sampleOrder.lines.single;

    expect(line.withDelivered(20).delivered, 12);
    expect(line.withDelivered(-1).delivered, 0);
  });

  test('the delivery part has the time in the field, items and place', () {
    expect(registrationJson(_record), {
      'deliveredAt': '2026-11-02T10:30:00',
      'items': [
        {'resourceId': 'r1', 'quantity': 12},
      ],
      'location': {'latitude': -11.9436, 'longitude': -76.7078},
    });
  });

  test('the multipart form types each part as the API requires', () async {
    final form = await registrationForm(_record, readFile: _fakeFile);

    final parts = {
      for (final entry in form.files)
        '${entry.key}:${entry.value.filename}': entry.value.contentType
            .toString(),
    };
    expect(parts, {
      'delivery:null': 'application/json; charset=utf-8',
      'evidences:/d/signature.png': 'image/png',
      'evidences:/d/reception.jpg': 'image/jpeg',
    });
  });

  test('registers the delivery and reads its integrity', () async {
    final adapter = FakeHttpAdapter({
      'POST /api/v1/deliveries/${sampleOrder.deliveryId}/registration': (
        201,
        {
          'id': sampleOrder.deliveryId,
          'status': 'REGISTERED',
          'integrity': {'recordHash': 'abc', 'anchorStatus': 'PENDING'},
        },
      ),
    });
    final gateway = HttpDeliveryGateway(
      fakeApiClient(adapter, token: 't'),
      readFile: _fakeFile,
    );

    final result = await gateway.register(_record);

    final integrity = result.getRight().toNullable()!;
    expect(integrity.anchorStatus, AnchorStatus.pending);
    expect(integrity.recordHash, 'abc');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer t');
  });

  test('a quantity above the plan is a rejected registration', () async {
    final adapter = FakeHttpAdapter({
      'POST /api/v1/deliveries/${sampleOrder.deliveryId}/registration': (
        422,
        {'detail': 'La cantidad supera la del plan.'},
      ),
    });
    final gateway = HttpDeliveryGateway(
      fakeApiClient(adapter),
      readFile: _fakeFile,
    );

    final failure = (await gateway.register(_record)).getLeft().toNullable()!;

    expect(failure, isA<ValidationFailure>());
    expect(failure.isRetryable, isFalse);
  });

  test('reads an anchored integrity', () {
    final integrity = integrityFromJson(
      jsonDecode('''
      {"integrity": {"recordHash": "h", "anchorStatus": "ANCHORED",
       "transactionHash": "0x1", "anchoredAt": "2026-11-02T10:31:00"}}
      ''')
          as Map<String, Object?>,
    );

    expect(integrity.recordStatus, DeliveryRecordStatus.anchored);
    expect(integrity.anchoredAt, DateTime.utc(2026, 11, 2, 10, 31));
  });
}
