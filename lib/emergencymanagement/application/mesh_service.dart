import 'dart:async';

import 'package:equatable/equatable.dart';

import '../domain/model/mesh_packet.dart';
import 'mesh_relay_service.dart';

/// The radio that finds nearby phones with AuxIA and talks to them without
/// internet: Bluetooth and Wi-Fi Direct (plan D5).
abstract interface class MeshNetwork {
  /// Whether this device can do Mesh at all (only Android, plan D5).
  bool get supported;

  /// Starts finding nearby phones and accepting them.
  Future<void> start({
    required void Function(String peer) onConnected,
    required void Function(String peer) onDisconnected,
    required void Function(String peer, List<int> bytes) onBytes,
  });

  Future<void> send(String peer, List<int> bytes);

  Future<void> stop();
}

/// Permissions of Bluetooth and nearby devices.
abstract interface class MeshPermissions {
  /// Asks for them if needed; true when Mesh can run.
  Future<bool> request();
}

/// Whether the user turned Mesh on (A_06 / A_09).
abstract interface class MeshSettings {
  Future<bool> enabled();

  Future<void> setEnabled(bool enabled);
}

/// State of Mesh shown on A_05, A_06 and A_09.
final class MeshState extends Equatable {
  const MeshState({
    this.supported = true,
    this.enabled = false,
    this.peers = 0,
    this.permissionDenied = false,
  });

  final bool supported;

  /// Turned on by the user, with the permissions granted.
  final bool enabled;

  /// Nearby phones connected right now.
  final int peers;

  /// The user turned it on but did not grant the permissions.
  final bool permissionDenied;

  /// The SOS can travel by Mesh right now.
  bool get available => enabled && peers > 0;

  MeshState copyWith({bool? enabled, int? peers, bool? permissionDenied}) =>
      MeshState(
        supported: supported,
        enabled: enabled ?? this.enabled,
        peers: peers ?? this.peers,
        permissionDenied: permissionDenied ?? this.permissionDenied,
      );

  @override
  List<Object> get props => [supported, enabled, peers, permissionDenied];
}

/// What the screens see of Mesh and the switch they turn.
abstract interface class MeshController {
  MeshState get state;

  Stream<MeshState> get states;

  Future<void> setEnabled(bool enabled);
}

/// Mesh of the phone (plan D5): while it is on, it connects to nearby phones
/// with AuxIA, gives them the SOS that did not leave yet and keeps theirs to
/// upload or pass on. It runs while the app is open.
class MeshService implements MeshController {
  MeshService(
    this._network,
    this._permissions,
    this._settings,
    this._relay, {
    this.resendEvery = const Duration(seconds: 30),
  }) : _state = MeshState(supported: _network.supported);

  final MeshNetwork _network;
  final MeshPermissions _permissions;
  final MeshSettings _settings;
  final MeshRelayService _relay;

  /// New SOS reach the phones already connected this often.
  final Duration resendEvery;

  final Set<String> _peers = {};
  final StreamController<MeshState> _states = StreamController.broadcast();
  MeshState _state;
  Timer? _resend;
  bool _running = false;

  @override
  MeshState get state => _state;

  @override
  Stream<MeshState> get states => _states.stream;

  /// Resumes Mesh if the user left it on.
  Future<void> start() async {
    if (!_state.supported || !await _settings.enabled()) return;
    if (!await _permissions.request()) {
      _emit(_state.copyWith(enabled: false, permissionDenied: true));
      return;
    }
    await _begin();
  }

  /// The switch of A_06 / A_09.
  @override
  Future<void> setEnabled(bool enabled) async {
    if (!_state.supported) return;
    if (!enabled) {
      await _settings.setEnabled(false);
      await _end();
      _emit(_state.copyWith(enabled: false, permissionDenied: false));
      return;
    }
    if (!await _permissions.request()) {
      _emit(_state.copyWith(enabled: false, permissionDenied: true));
      return;
    }
    await _settings.setEnabled(true);
    await _begin();
  }

  Future<void> _begin() async {
    _emit(_state.copyWith(enabled: true, permissionDenied: false));
    if (_running) return;
    _running = true;
    await _network.start(
      onConnected: (peer) {
        _peers.add(peer);
        _emit(_state.copyWith(peers: _peers.length));
        unawaited(_offer([peer]));
      },
      onDisconnected: (peer) {
        _peers.remove(peer);
        _emit(_state.copyWith(peers: _peers.length));
      },
      onBytes: (peer, bytes) {
        final packet = MeshPacket.decode(bytes);
        if (packet != null) unawaited(_relay.receive(packet));
      },
    );
    _resend = Timer.periodic(resendEvery, (_) => unawaited(_offer(_peers)));
  }

  Future<void> _end() async {
    _resend?.cancel();
    _resend = null;
    if (_running) await _network.stop();
    _running = false;
    _peers.clear();
    _emit(_state.copyWith(peers: 0));
  }

  /// Gives [peers] everything this phone can pass on. They ignore what they
  /// already have.
  Future<void> _offer(Iterable<String> peers) async {
    final targets = peers.toList();
    if (targets.isEmpty) return;
    final packets = await _relay.outgoing();
    for (final peer in targets) {
      for (final packet in packets) {
        try {
          await _network.send(peer, packet.encode());
        } on Exception {
          // The phone moved away: it gets them again when it reconnects.
          break;
        }
      }
    }
  }

  void _emit(MeshState state) {
    if (state == _state) return;
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> dispose() async {
    await _end();
    await _states.close();
  }
}
