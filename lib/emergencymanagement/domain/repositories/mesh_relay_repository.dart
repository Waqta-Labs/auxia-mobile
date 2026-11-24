import '../model/mesh_packet.dart';

/// SOS of other phones that this phone received by Mesh (plan D5).
abstract interface class MeshRelayRepository {
  Future<void> save(MeshRelay relay);

  Future<MeshRelay?> find(String clientReportId);

  /// Not uploaded yet, the oldest first.
  Future<List<MeshRelay>> pending();
}
