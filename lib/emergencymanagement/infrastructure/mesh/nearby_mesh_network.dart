import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../application/mesh_service.dart';

/// [MeshNetwork] over Google Nearby Connections: Bluetooth and Wi-Fi Direct
/// between Android phones, without internet (plan D5). Every phone both
/// advertises and discovers, in a cluster where any phone can talk to any
/// other.
class NearbyMeshNetwork implements MeshNetwork {
  NearbyMeshNetwork({Random? random})
    : _name = 'AuxIA-${(random ?? Random()).nextInt(0xFFFF).toRadixString(16)}';

  /// Only phones with AuxIA answer to this id.
  static const String serviceId = 'pe.waqtalabs.auxia.mesh';
  static const Strategy _strategy = Strategy.P2P_CLUSTER;

  /// Name shown to nearby phones; it says nothing about the user.
  final String _name;
  final Nearby _nearby = Nearby();
  final Set<String> _requested = {};

  late void Function(String peer) _onConnected;
  late void Function(String peer) _onDisconnected;
  late void Function(String peer, List<int> bytes) _onBytes;

  @override
  bool get supported => Platform.isAndroid;

  @override
  Future<void> start({
    required void Function(String peer) onConnected,
    required void Function(String peer) onDisconnected,
    required void Function(String peer, List<int> bytes) onBytes,
  }) async {
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;
    _onBytes = onBytes;
    try {
      await _nearby.startAdvertising(
        _name,
        _strategy,
        onConnectionInitiated: _accept,
        onConnectionResult: _result,
        onDisconnected: _disconnected,
        serviceId: serviceId,
      );
      await _nearby.startDiscovery(
        _name,
        _strategy,
        onEndpointFound: (peer, _, _) => _request(peer),
        onEndpointLost: (peer) {
          if (peer != null) _requested.remove(peer);
        },
        serviceId: serviceId,
      );
    } on PlatformException {
      // Bluetooth off or busy: Mesh shows no phones nearby.
    }
  }

  Future<void> _request(String peer) async {
    if (!_requested.add(peer)) return;
    try {
      await _nearby.requestConnection(
        _name,
        peer,
        onConnectionInitiated: _accept,
        onConnectionResult: _result,
        onDisconnected: _disconnected,
      );
    } on PlatformException {
      // Both phones asked at the same time: the other request wins.
      _requested.remove(peer);
    }
  }

  /// Any phone with AuxIA is accepted: what travels is an SOS anyone may
  /// upload, never personal data of this phone.
  void _accept(String peer, ConnectionInfo _) {
    _nearby
        .acceptConnection(
          peer,
          onPayLoadRecieved: (peer, payload) {
            final bytes = payload.bytes;
            if (payload.type == PayloadType.BYTES && bytes != null) {
              _onBytes(peer, bytes);
            }
          },
        )
        .catchError((Object _) => false);
  }

  void _result(String peer, Status status) {
    if (status == Status.CONNECTED) {
      _onConnected(peer);
    } else {
      _requested.remove(peer);
    }
  }

  void _disconnected(String peer) {
    _requested.remove(peer);
    _onDisconnected(peer);
  }

  @override
  Future<void> send(String peer, List<int> bytes) async {
    try {
      await _nearby.sendBytesPayload(peer, Uint8List.fromList(bytes));
    } on PlatformException catch (error) {
      throw MeshSendException('$error');
    }
  }

  @override
  Future<void> stop() async {
    _requested.clear();
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } on PlatformException {
      // Already stopped.
    }
  }
}

class MeshSendException implements Exception {
  MeshSendException(this.message);

  final String message;

  @override
  String toString() => 'MeshSendException: $message';
}

/// Bluetooth and nearby devices (Android 12 and later), or the location
/// that older Android versions ask to find nearby phones.
class DeviceMeshPermissions implements MeshPermissions {
  @override
  Future<bool> request() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
    ].request();
    bool granted(Permission permission) =>
        statuses[permission]?.isGranted ?? false;
    final bluetooth =
        granted(Permission.bluetoothScan) &&
        granted(Permission.bluetoothAdvertise) &&
        granted(Permission.bluetoothConnect);
    return bluetooth &&
        (granted(Permission.nearbyWifiDevices) ||
            granted(Permission.locationWhenInUse));
  }
}

/// [MeshSettings] in the `key_values` table: Mesh starts off.
class SqliteMeshSettings implements MeshSettings {
  SqliteMeshSettings(this._db);

  static const String _key = 'settings.mesh';

  final Database _db;

  @override
  Future<bool> enabled() async {
    final rows = await _db.query(
      'key_values',
      where: 'key = ?',
      whereArgs: [_key],
    );
    return rows.isNotEmpty && rows.first['value'] == 'on';
  }

  @override
  Future<void> setEnabled(bool enabled) => _db.insert('key_values', {
    'key': _key,
    'value': enabled ? 'on' : 'off',
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
