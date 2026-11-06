import 'package:equatable/equatable.dart';

import '../../../shared/domain/geo_point.dart';

/// A resource line of the delivery: what the plan assigned and what the
/// brigade hands over (it can be less, never more).
final class DeliveryLine extends Equatable {
  const DeliveryLine({
    required this.resourceId,
    required this.name,
    required this.planned,
    required this.delivered,
    this.unit,
  }) : assert(delivered >= 0 && delivered <= planned, 'out of the plan');

  final String resourceId;
  final String name;
  final String? unit;
  final int planned;
  final int delivered;

  DeliveryLine withDelivered(int quantity) => DeliveryLine(
    resourceId: resourceId,
    name: name,
    unit: unit,
    planned: planned,
    delivered: quantity.clamp(0, planned),
  );

  @override
  List<Object?> get props => [resourceId, name, unit, planned, delivered];
}

/// What the brigade must deliver, as the delivery check (A_08) receives it
/// from the mission.
final class DeliveryOrder extends Equatable {
  const DeliveryOrder({
    required this.deliveryId,
    required this.zoneName,
    required this.brigadeName,
    required this.lines,
  });

  /// Id of the delivery in the backend, the one the package QR carries.
  final String deliveryId;
  final String zoneName;
  final String brigadeName;
  final List<DeliveryLine> lines;

  /// Short code shown on the screen, such as #A-2041.
  String get shortCode => shortDeliveryCode(deliveryId);

  @override
  List<Object> get props => [deliveryId, zoneName, brigadeName, lines];
}

/// "#3F2A-91C0": the first eight hex digits of the id, easy to read aloud.
String shortDeliveryCode(String deliveryId) {
  final hex = deliveryId.replaceAll('-', '').toUpperCase();
  if (hex.length < 8) return '#$hex';
  return '#${hex.substring(0, 4)}-${hex.substring(4, 8)}';
}

/// Reads the delivery id from the package QR. The QR may hold the id itself
/// or the verification URL of the delivery
/// (`…/api/v1/deliveries/{id}/verify`). Returns null for anything else.
String? deliveryIdFromQr(String raw) {
  final match = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  ).firstMatch(raw.trim());
  return match?.group(0)?.toLowerCase();
}

/// Where the registration of a delivery is (report 6.2.5: Entrega → QR +
/// Firma + Fotografía → Hash confirmado → Misión completada).
enum DeliveryRecordStatus {
  /// Saved on the device, waiting for signal.
  queued,

  /// Registered in the backend; its hash is being anchored on Blockchain.
  registered,

  /// Hash anchored: "Validado e Inmutable en Blockchain".
  anchored,

  /// The backend registered it but the anchoring failed; it retries there.
  anchorFailed,

  /// The backend refused it (for example, a quantity above the plan).
  rejected,
}

/// Delivery registered from the device, with its evidence and its integrity.
final class DeliveryRecord extends Equatable {
  const DeliveryRecord({
    required this.order,
    required this.deliveredAt,
    required this.signaturePath,
    required this.photoPath,
    required this.status,
    this.location,
    this.recordHash,
    this.transactionHash,
    this.anchoredAt,
    this.rejection,
  });

  final DeliveryOrder order;

  /// Time of the delivery in the field, even if it is sent hours later.
  final DateTime deliveredAt;
  final String signaturePath;
  final String photoPath;
  final DeliveryRecordStatus status;
  final GeoPoint? location;

  /// SHA-256 of the record, without personal data (TS-C02).
  final String? recordHash;

  /// Transaction that anchored the hash (Sepolia).
  final String? transactionHash;
  final DateTime? anchoredAt;
  final String? rejection;

  String get deliveryId => order.deliveryId;

  DeliveryRecord withIntegrity(DeliveryIntegrity integrity) => DeliveryRecord(
    order: order,
    deliveredAt: deliveredAt,
    signaturePath: signaturePath,
    photoPath: photoPath,
    location: location,
    status: integrity.recordStatus,
    recordHash: integrity.recordHash ?? recordHash,
    transactionHash: integrity.transactionHash ?? transactionHash,
    anchoredAt: integrity.anchoredAt ?? anchoredAt,
  );

  DeliveryRecord rejected(String reason) => DeliveryRecord(
    order: order,
    deliveredAt: deliveredAt,
    signaturePath: signaturePath,
    photoPath: photoPath,
    location: location,
    status: DeliveryRecordStatus.rejected,
    rejection: reason,
  );

  @override
  List<Object?> get props => [
    order,
    deliveredAt,
    signaturePath,
    photoPath,
    status,
    location,
    recordHash,
    transactionHash,
    anchoredAt,
    rejection,
  ];
}

/// Anchoring status reported by the backend.
enum AnchorStatus { pending, anchored, failed }

/// Integrity of a delivery as the backend reports it.
final class DeliveryIntegrity extends Equatable {
  const DeliveryIntegrity({
    required this.anchorStatus,
    this.recordHash,
    this.transactionHash,
    this.anchoredAt,
  });

  final AnchorStatus anchorStatus;
  final String? recordHash;
  final String? transactionHash;
  final DateTime? anchoredAt;

  DeliveryRecordStatus get recordStatus => switch (anchorStatus) {
    AnchorStatus.pending => DeliveryRecordStatus.registered,
    AnchorStatus.anchored => DeliveryRecordStatus.anchored,
    AnchorStatus.failed => DeliveryRecordStatus.anchorFailed,
  };

  @override
  List<Object?> get props => [
    anchorStatus,
    recordHash,
    transactionHash,
    anchoredAt,
  ];
}
