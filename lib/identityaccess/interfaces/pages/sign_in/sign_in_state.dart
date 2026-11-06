part of 'sign_in_cubit.dart';

class SignInState extends Equatable {
  const SignInState({
    this.email = '',
    this.password = '',
    this.passwordVisible = false,
    this.emailError,
    this.passwordError,
    this.submitting = false,
    this.error,
  });

  final String email;
  final String password;
  final bool passwordVisible;
  final InvalidValueReason? emailError;
  final InvalidValueReason? passwordError;
  final bool submitting;
  final SignInError? error;

  SignInState copyWith({
    String? email,
    String? password,
    bool? passwordVisible,
    InvalidValueReason? Function()? emailError,
    InvalidValueReason? Function()? passwordError,
    bool? submitting,
    SignInError? Function()? error,
  }) => SignInState(
    email: email ?? this.email,
    password: password ?? this.password,
    passwordVisible: passwordVisible ?? this.passwordVisible,
    emailError: emailError != null ? emailError() : this.emailError,
    passwordError: passwordError != null ? passwordError() : this.passwordError,
    submitting: submitting ?? this.submitting,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [
    email,
    password,
    passwordVisible,
    emailError,
    passwordError,
    submitting,
    error,
  ];
}
