import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../application/auth_service.dart';
import '../application/profile_service.dart';
import '../domain/model/local_profile.dart';
import '../domain/model/session.dart';
import '../domain/model/user_role.dart';

enum ProfileStatus { loading, absent, present }

class ProfileState extends Equatable {
  const ProfileState._(this.status, [this.profile, this.session]);

  const ProfileState.loading() : this._(ProfileStatus.loading);
  const ProfileState.absent() : this._(ProfileStatus.absent);
  const ProfileState.present(LocalProfile profile, {Session? session})
    : this._(ProfileStatus.present, profile, session);

  final ProfileStatus status;
  final LocalProfile? profile;

  /// Institutional session of a brigadist, if they signed in (A_10).
  final Session? session;

  UserRole? get role => profile?.role;

  bool get isSignedIn => session != null;

  @override
  List<Object?> get props => [status, profile, session];
}

/// App-wide holder of the local profile and the brigadist session. The
/// router listens to it to send each role to its own bottom navigation.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._profiles, this._auth)
    : super(const ProfileState.loading());

  final ProfileService _profiles;
  final AuthService _auth;

  Future<void> load() async {
    final result = await _profiles.currentProfile();
    final profile = result.getOrElse((_) => null);
    if (profile == null) {
      emit(const ProfileState.absent());
      return;
    }
    final session = profile.isBrigadist ? await _auth.currentSession() : null;
    emit(ProfileState.present(profile, session: session));
  }

  /// Called after a successful registration (A_01 or A_02).
  void registered(LocalProfile profile) => emit(ProfileState.present(profile));

  /// Called after a successful sign-in (A_10).
  void signedIn(SignedIn result) =>
      emit(ProfileState.present(result.profile, session: result.session));

  /// "Cerrar sesión": the brigadist keeps the profile but loses the session.
  Future<void> signOut() async {
    await _auth.signOut();
    final profile = state.profile;
    emit(
      profile == null
          ? const ProfileState.absent()
          : ProfileState.present(profile),
    );
  }

  /// "Cambiar de rol": forgets the profile and the session and goes back to
  /// A_01.
  Future<void> reset() async {
    await _auth.signOut();
    await _profiles.resetProfile();
    emit(const ProfileState.absent());
  }
}
