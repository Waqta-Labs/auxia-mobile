import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/auth_service.dart';
import '../../../domain/model/valueobjects.dart';

part 'sign_in_state.dart';

/// Sign-in of brigadists with the institutional account (A_10).
class SignInCubit extends Cubit<SignInState> {
  SignInCubit(this._auth, {required this.onSignedIn})
    : super(const SignInState());

  final AuthService _auth;
  final void Function(SignedIn result) onSignedIn;

  void emailChanged(String value) => emit(
    state.copyWith(email: value, emailError: () => null, error: () => null),
  );

  void passwordChanged(String value) => emit(
    state.copyWith(
      password: value,
      passwordError: () => null,
      error: () => null,
    ),
  );

  void togglePasswordVisibility() =>
      emit(state.copyWith(passwordVisible: !state.passwordVisible));

  Future<void> submit() async {
    final emailError = _validate(() => InstitutionalEmail(state.email));
    final passwordError = _validate(() => Password(state.password));
    if (emailError != null || passwordError != null) {
      emit(
        state.copyWith(
          emailError: () => emailError,
          passwordError: () => passwordError,
        ),
      );
      return;
    }

    emit(state.copyWith(submitting: true, error: () => null));
    final result = await _auth.signIn(
      email: InstitutionalEmail(state.email),
      password: Password(state.password),
    );
    result.fold(
      (error) => emit(state.copyWith(submitting: false, error: () => error)),
      (signedIn) {
        emit(state.copyWith(submitting: false, password: ''));
        onSignedIn(signedIn);
      },
    );
  }

  static InvalidValueReason? _validate(Object Function() build) {
    try {
      build();
      return null;
    } on InvalidValueException catch (error) {
      return error.reason;
    }
  }
}
