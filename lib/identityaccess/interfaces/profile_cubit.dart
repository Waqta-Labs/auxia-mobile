import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../application/profile_service.dart';
import '../domain/model/local_profile.dart';
import '../domain/model/user_role.dart';

enum ProfileStatus { loading, absent, present }

class ProfileState extends Equatable {
  const ProfileState._(this.status, [this.profile]);

  const ProfileState.loading() : this._(ProfileStatus.loading);
  const ProfileState.absent() : this._(ProfileStatus.absent);
  const ProfileState.present(LocalProfile profile)
    : this._(ProfileStatus.present, profile);

  final ProfileStatus status;
  final LocalProfile? profile;

  UserRole? get role => profile?.role;

  @override
  List<Object?> get props => [status, profile];
}

/// App-wide holder of the local profile. The router listens to it to send
/// each role to its own bottom navigation.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._service) : super(const ProfileState.loading());

  final ProfileService _service;

  Future<void> load() async {
    final result = await _service.currentProfile();
    emit(
      result.fold(
        (_) => const ProfileState.absent(),
        (profile) => profile == null
            ? const ProfileState.absent()
            : ProfileState.present(profile),
      ),
    );
  }

  /// Called after a successful registration.
  void registered(LocalProfile profile) => emit(ProfileState.present(profile));

  /// "Cambiar de rol": forgets the profile and goes back to A_01.
  Future<void> reset() async {
    await _service.resetProfile();
    emit(const ProfileState.absent());
  }
}
