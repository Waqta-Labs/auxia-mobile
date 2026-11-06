import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';

/// Channels the app can use to reach the backend.
///
/// The mockups also show Mesh and Satellite (A_05). A phone cannot open those
/// channels by itself, so they are listed as unavailable on this device
/// (TS-C08: controlled MVP scenario).
enum NetworkChannel { cellular, wifi, other }

/// Network state of the device.
final class NetworkStatus extends Equatable {
  const NetworkStatus(this.channels);

  const NetworkStatus.offline() : channels = const {};

  final Set<NetworkChannel> channels;

  bool get isOnline => channels.isNotEmpty;

  @override
  List<Object> get props => [channels];
}

/// Port that tells whether the device has network.
abstract interface class ConnectivityMonitor {
  Future<NetworkStatus> current();

  Stream<NetworkStatus> get changes;
}

/// [ConnectivityMonitor] over `connectivity_plus`.
///
/// It reports the interfaces of the device; the sync engine still treats a
/// failed request as offline, because a Wi-Fi without internet also exists.
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkStatus> current() async =>
      _toStatus(await _connectivity.checkConnectivity());

  @override
  Stream<NetworkStatus> get changes =>
      _connectivity.onConnectivityChanged.map(_toStatus).distinct();

  static NetworkStatus _toStatus(List<ConnectivityResult> results) {
    final channels = <NetworkChannel>{
      for (final result in results)
        if (result == ConnectivityResult.mobile)
          NetworkChannel.cellular
        else if (result == ConnectivityResult.wifi)
          NetworkChannel.wifi
        else if (result == ConnectivityResult.ethernet ||
            result == ConnectivityResult.vpn ||
            result == ConnectivityResult.other)
          NetworkChannel.other,
    };
    return NetworkStatus(channels);
  }
}
