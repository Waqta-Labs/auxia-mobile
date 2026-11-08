import 'dart:convert';

import 'package:equatable/equatable.dart';

/// An SOS travelling from phone to phone by Mesh, without internet (plan D5).
///
/// It carries the same JSON the origin phone would send to
/// `POST /public/field-reports`, without photo or audio. [hops] counts the
/// phones that relayed it before the one receiving it: the origin sends 0.
final class MeshPacket extends Equatable {
  const MeshPacket({
    required this.clientReportId,
    required this.body,
    required this.hops,
  });

  /// Phones an SOS may go through, the uploader included (plan D5).
  static const int maxHops = 3;

  /// An older SOS is no longer passed on (plan D5).
  static const Duration maxAge = Duration(hours: 24);

  static const int _format = 1;

  final String clientReportId;

  /// Body of `POST /public/field-reports`, as the origin phone built it.
  final Map<String, Object?> body;
  final int hops;

  /// When the SOS was sent on the origin phone, from `reportedAt` (UTC).
  DateTime? get reportedAt {
    final raw = body['reportedAt'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw.endsWith('Z') ? raw : '${raw}Z');
  }

  /// Too old to keep travelling, or without a readable time.
  bool isExpiredAt(DateTime now) {
    final sent = reportedAt;
    return sent == null || now.difference(sent) > maxAge;
  }

  List<int> encode() => utf8.encode(
    jsonEncode({
      'v': _format,
      'id': clientReportId,
      'hops': hops,
      'body': body,
    }),
  );

  /// Reads a packet from another phone; null when it is not one.
  static MeshPacket? decode(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, Object?> || json['v'] != _format) return null;
      final id = json['id'];
      final hops = json['hops'];
      final body = json['body'];
      if (id is! String || hops is! int || body is! Map<String, Object?>) {
        return null;
      }
      if (body['clientReportId'] != id || hops < 0 || hops >= maxHops) {
        return null;
      }
      return MeshPacket(clientReportId: id, body: body, hops: hops);
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object> get props => [clientReportId, body, hops];
}

/// An SOS of another phone that this phone holds to upload or pass on.
final class MeshRelay extends Equatable {
  const MeshRelay({
    required this.clientReportId,
    required this.body,
    required this.hops,
    required this.receivedAt,
    this.uploaded = false,
  });

  final String clientReportId;
  final Map<String, Object?> body;

  /// Phones it went through, this one included: `relay.hops` on upload.
  final int hops;
  final DateTime receivedAt;

  /// Already in the backend: nothing left to do with it.
  final bool uploaded;

  /// The packet that passes it on to the next phone.
  MeshPacket get packet =>
      MeshPacket(clientReportId: clientReportId, body: body, hops: hops);

  MeshRelay markUploaded() => MeshRelay(
    clientReportId: clientReportId,
    body: body,
    hops: hops,
    receivedAt: receivedAt,
    uploaded: true,
  );

  @override
  List<Object> get props => [clientReportId, body, hops, receivedAt, uploaded];
}
