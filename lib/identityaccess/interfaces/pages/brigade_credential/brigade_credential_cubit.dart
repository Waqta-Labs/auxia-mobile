import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/profile_service.dart';
import '../../../domain/model/local_profile.dart';
import '../../../domain/model/valueobjects.dart';
import '../registration/registration_cubit.dart';

part 'brigade_credential_state.dart';

/// Takes the photo of the ID card; returns null if the user cancelled.
typedef CaptureIdCard = Future<String?> Function();

/// Brigade credential (A_02), step 2 of the brigadist registration.
class BrigadeCredentialCubit extends Cubit<BrigadeCredentialState> {
  BrigadeCredentialCubit(
    this._service, {
    required this.pending,
    required this.captureIdCard,
    required this.onRegistered,
  }) : super(const BrigadeCredentialState());

  final ProfileService _service;
  final PendingRegistration pending;
  final CaptureIdCard captureIdCard;
  final void Function(LocalProfile profile) onRegistered;

  void organizationChanged(String value) =>
      emit(state.copyWith(organization: value, organizationError: () => null));

  void brigadeCodeChanged(String value) =>
      emit(state.copyWith(brigadeCode: value, brigadeCodeError: () => null));

  Future<void> scanIdCard() async {
    try {
      final path = await captureIdCard();
      if (path != null) {
        emit(state.copyWith(idCardPhotoPath: () => path, cameraFailed: false));
      }
    } on Exception {
      emit(state.copyWith(cameraFailed: true));
    }
  }

  Future<void> submit() async {
    final organizationError = _validate(
      () => OrganizationName(state.organization),
    );
    final brigadeCodeError = _validate(() => BrigadeCode(state.brigadeCode));
    if (organizationError != null || brigadeCodeError != null) {
      emit(
        state.copyWith(
          organizationError: () => organizationError,
          brigadeCodeError: () => brigadeCodeError,
        ),
      );
      return;
    }

    emit(state.copyWith(submitting: true, failed: false));
    final result = await _service.registerBrigadist(
      fullName: pending.fullName,
      phone: pending.phone,
      organization: OrganizationName(state.organization),
      brigadeCode: BrigadeCode(state.brigadeCode),
      idCardPhotoPath: state.idCardPhotoPath,
    );
    result.fold((_) => emit(state.copyWith(submitting: false, failed: true)), (
      profile,
    ) {
      emit(state.copyWith(submitting: false, submitted: true));
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
