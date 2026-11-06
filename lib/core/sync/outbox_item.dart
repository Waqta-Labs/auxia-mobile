import 'package:equatable/equatable.dart';

/// Life cycle of a write waiting in the outbox.
enum OutboxStatus {
  /// Saved on the device, waiting for its turn or for signal.
  pending,

  /// Being sent right now ("Transmitiendo").
  sending,

  /// Accepted by the backend.
  sent,

  /// Refused by a business or validation rule; retrying would fail again.
  rejected;

  static OutboxStatus fromName(String name) =>
      OutboxStatus.values.firstWhere((status) => status.name == name);
}

/// A write saved on the device that must reach the backend (TS-C06).
final class OutboxItem extends Equatable {
  const OutboxItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  /// Id generated on the device. The backend uses it to ignore duplicates.
  final String id;

  /// Which handler sends it, such as `citizen_report` or `delivery`.
  final String type;
  final Map<String, Object?> payload;
  final OutboxStatus status;
  final int attempts;
  final DateTime nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;

  @override
  List<Object?> get props => [
    id,
    type,
    payload,
    status,
    attempts,
    nextAttemptAt,
    createdAt,
    updatedAt,
    lastError,
  ];
}
