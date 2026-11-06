import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/profile_service.dart';
import '../../../domain/model/local_profile.dart';
import '../../../domain/model/user_role.dart';
import '../../../domain/model/valueobjects.dart';

part 'registration_state.dart';

/// Data typed on A_01 that the credential step (A_02) completes.
class PendingRegistration extends Equatable {
  const PendingRegistration({required this.fullName, required this.phone});

  final FullName fullName;
  final PhoneNumber phone;

  @override
  List<Object> get props => [fullName, phone];
}

/// Registration and role selection (A_01).
class RegistrationCubit extends Cubit<RegistrationState> {
  RegistrationCubit(this._service, {required this.onRegistered})
    : super(const RegistrationState());

  final ProfileService _service;

  /// Notifies the app that a profile exists, so the router changes shell.
  final void Function(LocalProfile profile) onRegistered;

  void nameChanged(String value) => emit(
    state.copyWith(
      fullName: value,
      nameError: () => null,
      outcome: RegistrationOutcome.none,
    ),
  );

  void phoneChanged(String value) => emit(
    state.copyWith(
      phone: value,
      phoneError: () => null,
      outcome: RegistrationOutcome.none,
    ),
  );

  void roleSelected(UserRole role) =>
      emit(state.copyWith(role: role, outcome: RegistrationOutcome.none));

  /// Validated name and phone, available after a valid [submit].
  PendingRegistration? get pending {
    try {
      return PendingRegistration(
        fullName: FullName(state.fullName),
        phone: PhoneNumber(state.phone),
      );
    } on InvalidValueException {
      return null;
    }
  }

  Future<void> submit() async {
    final nameError = _validate(() => FullName(state.fullName));
    final phoneError = _validate(() => PhoneNumber(state.phone));
    if (nameError != null || phoneError != null) {
      emit(
        state.copyWith(
          nameError: () => nameError,
          phoneError: () => phoneError,
          outcome: RegistrationOutcome.none,
        ),
      );
      return;
    }

    if (state.role == UserRole.brigadist) {
      emit(state.copyWith(outcome: RegistrationOutcome.continueToCredential));
      return;
    }

    emit(state.copyWith(submitting: true, failed: false));
    final result = await _service.registerCitizen(
      fullName: FullName(state.fullName),
      phone: PhoneNumber(state.phone),
    );
    result.fold((_) => emit(state.copyWith(submitting: false, failed: true)), (
      profile,
    ) {
      emit(
        state.copyWith(
          submitting: false,
          outcome: RegistrationOutcome.citizenRegistered,
        ),
      );
      onRegistered(profile);
    });
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
