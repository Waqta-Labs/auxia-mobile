import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../application/auth_service.dart';
import '../application/brigade_registration_service.dart';
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
  ProfileCubit(this._profiles, this._auth, {this.registrations})
    : super(const ProfileState.loading());

  final ProfileService _profiles;
  final AuthService _auth;

  /// Follows the credential of A_02 until it is approved (plan D3).
  final BrigadeRegistrationService? registrations;
  Future<void>? _checking;

  Future<void> load() async {
    final result = await _profiles.currentProfile();
    final profile = result.getOrElse((_) => null);
    if (profile == null) {
      emit(const ProfileState.absent());
      return;
    }
    final session = profile.isBrigadist ? await _auth.currentSession() : null;
    emit(ProfileState.present(profile, session: session));
    if (profile.credential != null) await checkRegistration();
  }

  /// Asks whether the credential of A_02 was decided and, once approved,
  /// enters with the device secret. Called on start, after each sync pass
  /// and from A_07. Concurrent calls share one check.
  Future<void> checkRegistration() =>
      _checking ??= _check().whenComplete(() => _checking = null);

  Future<void> _check() async {
    final service = registrations;
    final credential = state.profile?.credential;
    if (service == null || credential == null) return;
    if (!credential.isPending && !credential.isApproved) return;
    final check = await service.refresh();
    if (check == null || isClosed) return;
    emit(
      ProfileState.present(
        check.profile,
        session: check.session ?? state.session,
      ),
    );
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
