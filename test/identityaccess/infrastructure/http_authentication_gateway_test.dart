import 'package:auxia_mobile/identityaccess/domain/model/session.dart';
import 'package:auxia_mobile/identityaccess/infrastructure/api/http_authentication_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the authenticated user resource of the backend', () {
    final session = authenticatedUserFromJson({
      'token': 'eyJ...',
      'tokenType': 'Bearer',
      'expiresAt': '2026-11-06T17:30:00',
      'userId': '2b1c',
      'organizationId': '9f0a',
      'role': 'FIELD_BRIGADE',
      'fullName': 'Cap. M. Quispe',
    });

    expect(session.token, 'eyJ...');
    expect(session.role, AccountRole.fieldBrigade);
    expect(session.fullName, 'Cap. M. Quispe');
    expect(session.expiresAt, DateTime.utc(2026, 11, 6, 17, 30));
  });

  test('keeps an explicit time zone', () {
    final session = authenticatedUserFromJson({
      'token': 't',
      'expiresAt': '2026-11-06T17:30:00Z',
      'userId': 'u',
      'organizationId': 'o',
      'role': 'AUTHORITY',
      'fullName': 'Luis Salazar',
    });

    expect(session.expiresAt, DateTime.utc(2026, 11, 6, 17, 30));
    expect(session.role, AccountRole.authority);
  });
}
