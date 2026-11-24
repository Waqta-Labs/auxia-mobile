import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../../core/sync/outbox_item.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/sync_engine.dart';
import '../domain/model/citizen_report.dart';
import '../domain/model/mesh_packet.dart';
import '../domain/repositories/citizen_report_gateway.dart';
import '../domain/repositories/citizen_report_repository.dart';
import '../domain/repositories/mesh_relay_repository.dart';
import 'sos_service.dart';

/// What travels by Mesh (plan D5): the SOS of this phone that did not leave
/// yet, and the SOS of other phones, until one with signal uploads them.
class MeshRelayService {
  MeshRelayService(
    this._reports,
    this._relays,
    this._outbox, {
    required this.bodyOf,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CitizenReportRepository _reports;
  final MeshRelayRepository _relays;
  final OutboxRepository _outbox;
  final DateTime Function() _clock;

  /// Body of `POST /public/field-reports` for an SOS of this phone.
  final Map<String, Object?> Function(CitizenReport report) bodyOf;

  /// What this phone offers to a nearby phone: its own SOS still waiting to
  /// leave, and the SOS of others it can still pass on.
  Future<List<MeshPacket>> outgoing() async {
    final now = _clock();
    final packets = <MeshPacket>[];
    for (final report in await _reports.all()) {
      if (report.status != CitizenReportStatus.saved &&
          report.status != CitizenReportStatus.transmitting) {
        continue;
      }
      final packet = MeshPacket(
        clientReportId: report.id,
        body: bodyOf(report),
        hops: 0,
      );
      if (!packet.isExpiredAt(now)) packets.add(packet);
    }
    for (final relay in await _relays.pending()) {
      final packet = relay.packet;
      if (relay.hops < MeshPacket.maxHops && !packet.isExpiredAt(now)) {
        packets.add(packet);
      }
    }
    return packets;
  }

  /// Keeps an SOS received from a nearby phone and queues its upload. False
  /// when there is nothing to do: it is an SOS of this phone, it already
  /// arrived, it is older than 24 h or it went through too many phones.
  Future<bool> receive(MeshPacket packet) async {
    final now = _clock();
    if (packet.isExpiredAt(now) || packet.hops >= MeshPacket.maxHops) {
      return false;
    }
    final id = packet.clientReportId;
    if (await _reports.find(id) != null || await _relays.find(id) != null) {
      return false;
    }
    await _relays.save(
      MeshRelay(
        clientReportId: id,
        body: packet.body,
        hops: packet.hops + 1,
        receivedAt: now,
      ),
    );
    await _outbox.enqueue(
      type: CitizenOutboxTypes.relay,
      payload: {'clientReportId': id},
      id: 'relay-$id',
    );
    return true;
  }
}

/// Uploads an SOS that another phone passed by Mesh, with `relay.hops`. The
/// backend keeps one SOS per `clientReportId`, so it does not matter which
/// phone uploads it first.
class RelayedSosHandler implements OutboxHandler {
  RelayedSosHandler(this._relays, this._gateway);

  final MeshRelayRepository _relays;
  final CitizenReportGateway _gateway;

  @override
  String get type => CitizenOutboxTypes.relay;

  @override
  Future<Either<Failure, Unit>> send(OutboxItem item) async {
    final relay = await _relays.find(item.payload['clientReportId']! as String);
    if (relay == null || relay.uploaded) return const Right(unit);
    final result = await _gateway.submitRelayed(relay.body, hops: relay.hops);
    if (result.isRight()) await _relays.save(relay.markUploaded());
    return result;
  }
}
