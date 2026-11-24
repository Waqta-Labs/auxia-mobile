import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _invalid(InvalidValueReason reason) => throwsA(
  isA<InvalidValueException>().having((e) => e.reason, 'reason', reason),
);

void main() {
  group('FullName', () {
    test('trims and collapses spaces', () {
      expect(FullName('  María   Quispe ').value, 'María Quispe');
    });

    test('exposes the initial for the avatar', () {
      expect(FullName('maría quispe').initial, 'M');
    });

    test('rejects empty, short and long names', () {
      expect(() => FullName('  '), _invalid(InvalidValueReason.nameRequired));
      expect(() => FullName('Al'), _invalid(InvalidValueReason.nameTooShort));
      expect(
        () => FullName('a' * 121),
        _invalid(InvalidValueReason.nameTooLong),
      );
    });
  });

  group('PhoneNumber', () {
    test('accepts local and international numbers', () {
      expect(PhoneNumber('+51 987 654 321').value, '+51 987 654 321');
      expect(PhoneNumber('987654321').value, '987654321');
      expect(PhoneNumber('(01) 555-1234').value, '(01) 555-1234');
    });

    test('rejects empty and malformed numbers', () {
      expect(() => PhoneNumber(''), _invalid(InvalidValueReason.phoneRequired));
      expect(
        () => PhoneNumber('12345'),
        _invalid(InvalidValueReason.phoneInvalid),
      );
      expect(
        () => PhoneNumber('98765abc'),
        _invalid(InvalidValueReason.phoneInvalid),
      );
    });
  });

  group('BrigadeCode', () {
    test('is stored in upper case', () {
      expect(BrigadeCode(' brg-alfa-07 ').value, 'BRG-ALFA-07');
    });

    test('rejects empty and invalid codes', () {
      expect(
        () => BrigadeCode(''),
        _invalid(InvalidValueReason.brigadeCodeRequired),
      );
      expect(
        () => BrigadeCode('BRG ALFA'),
        _invalid(InvalidValueReason.brigadeCodeInvalid),
      );
    });
  });

  test('OrganizationName is required', () {
    expect(
      () => OrganizationName(' '),
      _invalid(InvalidValueReason.organizationRequired),
    );
    expect(
      OrganizationName('Defensa Civil · Región Lima').value,
      'Defensa Civil · Región Lima',
    );
  });
}
