import '../model/local_profile.dart';

/// Port to keep the local profile on the device.
abstract interface class ProfileRepository {
  /// The saved profile, or null on the first launch.
  Future<LocalProfile?> load();

  Future<void> save(LocalProfile profile);

  /// Removes the profile, to register again with another role.
  Future<void> clear();
}
