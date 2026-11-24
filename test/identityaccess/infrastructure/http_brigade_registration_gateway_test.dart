import 'dart:convert';

import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/identityaccess/domain/model/brigade_credential.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:auxia_mobile/identityaccess/infrastructure/api/http_authentication_gateway.dart';
import 'package:auxia_mobile/identityaccess/infrastructure/api/http_brigade_registration_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final _credential = BrigadeCredential(
  registrationId: 'r1',
  deviceSecret: 's' * 44,
  organization: OrganizationName('Defensa Civil'),
  brigadeCode: BrigadeCode('BRG-ALFA-07'),
  submittedAt: DateTime(2026, 11, 7),
  idCardPhotoPath: '/cards/id.png',
);

const _signedIn = {
  'token': 'jwt',
  'tokenType': 'Bearer',
  'expiresAt': '2026-11-07T17:41:05.123456789',
  'userId': 'u1',
  'organizationId': 'o1',
  'role': 'FIELD_BRIGADE',
  'fullName': 'Miguel Quispe',
};

void main() {
  test('sends the registration part as JSON and the ID card', () async {
    final adapter = FakeHttpAdapter({
      'PUT /api/v1/public/brigade-registrations/r1': (
        201,
        {'status': 'PENDING', 'reason': null},
      ),
    });
    final readTypes = <String>[];

    final result = await HttpBrigadeRegistrationGateway(
      fakeApiClient(adapter, token: 'not-sent'),
      readFile: (path, type) async {
        readTypes.add(type.mimeType);
        return MultipartFile.fromBytes([1], filename: 'id.png');
      },
    ).submit(_credential, fullName: 'Miguel Quispe', phone: '987654321');

    expect(result.isRight(), isTrue);
    final request = adapter.requests.single;
    expect(request.headers['Authorization'], isNull);
    final form = request.data as FormData;
    final registration = form.files.firstWhere(
      (part) => part.key == 'registration',
    );
    expect(registration.value.contentType?.mimeType, 'application/json');
    expect(form.files.map((part) => part.key), contains('idCard'));
    expect(readTypes, ['image/png']);
  });

  test('the registration JSON carries the secret of the device', () async {
    final form = await registrationForm(
      _credential,
      fullName: 'Miguel Quispe',
      phone: '987654321',
      readFile: (path, type) async => MultipartFile.fromBytes([1]),
    );
    final part = form.files.firstWhere((part) => part.key == 'registration');
    final json =
        jsonDecode(await utf8.decodeStream(part.value.finalize()))
            as Map<String, Object?>;

    expect(json, {
      'fullName': 'Miguel Quispe',
      'phone': '987654321',
      'organization': 'Defensa Civil',
      'brigadeCode': 'BRG-ALFA-07',
      'deviceSecret': 's' * 44,
    });
  });

  test('asks for the decision with the device secret', () async {
    final adapter = FakeHttpAdapter({
      'GET /api/v1/public/brigade-registrations/r1': (
        200,
        {'status': 'REJECTED', 'reason': 'Carnet ilegible'},
      ),
    });

    final result = await HttpBrigadeRegistrationGateway(
      fakeApiClient(adapter),
    ).status(_credential);

    final decision = result.getRight().toNullable()!;
    expect(decision.status, CredentialStatus.rejected);
    expect(decision.reason, 'Carnet ilegible');
    expect(adapter.requests.single.headers['X-Device-Secret'], 's' * 44);
  });

  test('an unknown brigade code is not found', () async {
    final adapter = FakeHttpAdapter({});

    final result = await HttpBrigadeRegistrationGateway(
      fakeApiClient(adapter),
      readFile: (path, type) async => MultipartFile.fromBytes([1]),
    ).submit(_credential, fullName: 'M', phone: '9');

    expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
  });

  test('signs in with the registration id and the device secret', () async {
    final adapter = FakeHttpAdapter({
      'POST /api/v1/auth/device-sign-in': (200, _signedIn),
    });

    final result = await HttpAuthenticationGateway(
      fakeApiClient(adapter),
    ).deviceSignIn(registrationId: 'r1', deviceSecret: 's' * 44);

    expect(result.getRight().toNullable()!.token, 'jwt');
    expect(adapter.requests.single.data, {
      'registrationId': 'r1',
      'deviceSecret': 's' * 44,
    });
  });
}
