part of 'registration_cubit.dart';

/// Where the registration goes after "Continuar".
enum RegistrationOutcome {
  none,

  /// Citizen profile saved: the app opens the SOS screen.
  citizenRegistered,

  /// Brigadist: continue to the credential step (A_02).
  continueToCredential,
}

class RegistrationState extends Equatable {
  const RegistrationState({
    this.fullName = '',
    this.phone = '',
    this.role = UserRole.citizen,
    this.nameError,
    this.phoneError,
    this.submitting = false,
    this.failed = false,
    this.outcome = RegistrationOutcome.none,
  });

  final String fullName;
  final String phone;
  final UserRole role;
  final InvalidValueReason? nameError;
  final InvalidValueReason? phoneError;
  final bool submitting;
  final bool failed;
  final RegistrationOutcome outcome;

  RegistrationState copyWith({
    String? fullName,
    String? phone,
    UserRole? role,
    InvalidValueReason? Function()? nameError,
    InvalidValueReason? Function()? phoneError,
    bool? submitting,
    bool? failed,
    RegistrationOutcome? outcome,
  }) => RegistrationState(
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    nameError: nameError != null ? nameError() : this.nameError,
    phoneError: phoneError != null ? phoneError() : this.phoneError,
    submitting: submitting ?? this.submitting,
    failed: failed ?? this.failed,
    outcome: outcome ?? this.outcome,
  );

  @override
  List<Object?> get props => [
    fullName,
    phone,
    role,
    nameError,
    phoneError,
    submitting,
    failed,
    outcome,
  ];
}
