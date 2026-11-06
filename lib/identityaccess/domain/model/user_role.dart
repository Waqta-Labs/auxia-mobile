/// Role chosen on the registration screen (A_01). It decides which bottom
/// navigation the user gets (report 6.2.5).
enum UserRole {
  /// Asks for help with the one-tap SOS and follows the status of the reports.
  citizen,

  /// Field brigade member: missions, navigation and verified deliveries.
  brigadist;

  static UserRole fromName(String name) =>
      UserRole.values.firstWhere((role) => role.name == name);
}
