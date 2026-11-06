import 'package:equatable/equatable.dart';

/// Thrown when a value object receives an invalid value. The UI translates
/// the [reason] into a localized message.
class InvalidValueException implements Exception {
  const InvalidValueException(this.reason);

  final InvalidValueReason reason;

  @override
  String toString() => 'InvalidValueException($reason)';
}

enum InvalidValueReason {
  nameRequired,
  nameTooShort,
  nameTooLong,
  phoneRequired,
  phoneInvalid,
  organizationRequired,
  brigadeCodeRequired,
  brigadeCodeInvalid,
  emailRequired,
  emailInvalid,
  passwordRequired,
}

/// Full name of the person using the app.
final class FullName extends Equatable {
  factory FullName(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) {
      throw const InvalidValueException(InvalidValueReason.nameRequired);
    }
    if (value.length < minLength) {
      throw const InvalidValueException(InvalidValueReason.nameTooShort);
    }
    if (value.length > maxLength) {
      throw const InvalidValueException(InvalidValueReason.nameTooLong);
    }
    return FullName._(value);
  }

  const FullName._(this.value);

  static const int minLength = 3;
  static const int maxLength = 120;

  final String value;

  /// First letter, for the avatar of the settings screen.
  String get initial => String.fromCharCode(value.runes.first).toUpperCase();

  @override
  List<Object> get props => [value];
}

/// Phone number with an optional country code, such as +51 987 654 321.
final class PhoneNumber extends Equatable {
  factory PhoneNumber(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) {
      throw const InvalidValueException(InvalidValueReason.phoneRequired);
    }
    final digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(digits)) {
      throw const InvalidValueException(InvalidValueReason.phoneInvalid);
    }
    return PhoneNumber._(value);
  }

  const PhoneNumber._(this.value);

  final String value;

  @override
  List<Object> get props => [value];
}

/// Response organization of a brigade member, such as
/// "Defensa Civil · Región Lima".
final class OrganizationName extends Equatable {
  factory OrganizationName(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) {
      throw const InvalidValueException(
        InvalidValueReason.organizationRequired,
      );
    }
    return OrganizationName._(value);
  }

  const OrganizationName._(this.value);

  final String value;

  @override
  List<Object> get props => [value];
}

/// Code of the brigade, such as BRG-ALFA-07. Stored in upper case.
final class BrigadeCode extends Equatable {
  factory BrigadeCode(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) {
      throw const InvalidValueException(InvalidValueReason.brigadeCodeRequired);
    }
    if (!RegExp(r'^[A-Z0-9][A-Z0-9\-]{2,31}$').hasMatch(value)) {
      throw const InvalidValueException(InvalidValueReason.brigadeCodeInvalid);
    }
    return BrigadeCode._(value);
  }

  const BrigadeCode._(this.value);

  final String value;

  @override
  List<Object> get props => [value];
}

/// Institutional e-mail of an account created by the organization
/// administrator, such as m.quispe@coerlima.gob.pe.
final class InstitutionalEmail extends Equatable {
  factory InstitutionalEmail(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) {
      throw const InvalidValueException(InvalidValueReason.emailRequired);
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      throw const InvalidValueException(InvalidValueReason.emailInvalid);
    }
    return InstitutionalEmail._(value);
  }

  const InstitutionalEmail._(this.value);

  final String value;

  @override
  List<Object> get props => [value];
}

/// Password typed on the sign-in screen. It is never stored.
final class Password extends Equatable {
  factory Password(String raw) {
    if (raw.isEmpty) {
      throw const InvalidValueException(InvalidValueReason.passwordRequired);
    }
    return Password._(raw);
  }

  const Password._(this.value);

  final String value;

  @override
  List<Object> get props => [value];

  @override
  String toString() => 'Password(***)';
}
