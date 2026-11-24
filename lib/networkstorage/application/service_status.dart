import 'package:equatable/equatable.dart';

/// Cloud services the app depends on.
enum CloudService { backend, aiService }

/// Whether a service answered its health check.
enum ServiceHealth { unknown, checking, up, down }

/// Health of every [CloudService], as last checked.
final class ServiceStatus extends Equatable {
  const ServiceStatus({this.health = const {}, this.checkedAt});

  final Map<CloudService, ServiceHealth> health;
  final DateTime? checkedAt;

  ServiceHealth of(CloudService service) =>
      health[service] ?? ServiceHealth.unknown;

  bool get checking => health.values.contains(ServiceHealth.checking);

  /// One health for the whole cloud, as the user needs it: down when any
  /// service did not answer, up only when every service answered.
  ServiceHealth get overall {
    if (checking) return ServiceHealth.checking;
    final all = CloudService.values.map(of);
    if (all.contains(ServiceHealth.down)) return ServiceHealth.down;
    if (all.every((health) => health == ServiceHealth.up)) {
      return ServiceHealth.up;
    }
    return ServiceHealth.unknown;
  }

  @override
  List<Object?> get props => [health, checkedAt];
}

/// Port to the health checks of the cloud services. It needs no session:
/// before a demo it tells whether the cloud is up, or still waking up.
abstract interface class ServiceHealthProbe {
  /// True when [service] answered its health check as up.
  Future<bool> isUp(CloudService service);
}
