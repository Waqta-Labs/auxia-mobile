import 'package:equatable/equatable.dart';

/// Role of an institutional account in the backend (Identity Access).
enum AccountRole {
  organizationAdmin('ORGANIZATION_ADMIN'),
  authority('AUTHORITY'),
  fieldBrigade('FIELD_BRIGADE'),
  auditor('AUDITOR');

  const AccountRole(this.code);

  final String code;

  static AccountRole fromCode(String code) =>
      AccountRole.values.firstWhere((role) => role.code == code);
}

/// Session of a brigadist signed in with the institutional account (A_10).
///
/// The token lasts 8 hours. It is kept on the device so the app keeps
/// working without signal after the first sign-in; when it expires, the app
/// still shows what it saved and asks for a new sign-in before syncing.
final class Session extends Equatable {
  const Session({
    required this.token,
    required this.expiresAt,
    required this.userId,
    required this.organizationId,
    required this.role,
    required this.fullName,
  });

  final String token;
  final DateTime expiresAt;
  final String userId;
  final String organizationId;
  final AccountRole role;
  final String fullName;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  @override
  List<Object> get props => [
    token,
    expiresAt,
    userId,
    organizationId,
    role,
    fullName,
  ];
}
