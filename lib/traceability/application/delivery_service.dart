import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../../core/sync/outbox_item.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/sync_engine.dart';
import '../../shared/domain/geo_point.dart';
import '../domain/model/delivery.dart';
import '../domain/repositories/delivery_ports.dart';

/// Outbox type of a delivery registration.
const String deliveryOutboxType = 'delivery_registration';

/// Use cases of the delivery check (A_08, US-15, US-16, US-18).
class DeliveryService {
  DeliveryService(
    this._records,
    this._outbox,
    this._gateway, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DeliveryRecordRepository _records;
  final OutboxRepository _outbox;
  final DeliveryGateway _gateway;
  final DateTime Function() _clock;

  Future<DeliveryRecord?> find(String deliveryId) => _records.find(deliveryId);

  Stream<void> get changes => _records.changes;

  /// Saves the delivery with its evidence and queues its registration. It
  /// works without signal: the record keeps the time of the delivery in the
  /// field (R-02). A delivery the backend refused can be corrected and saved
  /// again.
  Future<Either<Failure, DeliveryRecord>> register({
    required DeliveryOrder order,
    required String signaturePath,
    required String photoPath,
    GeoPoint? location,
  }) async {
    if (order.lines.every((line) => line.delivered == 0)) {
      return const Left(ValidationFailure('Nothing to deliver'));
    }
    try {
      final record = DeliveryRecord(
        order: order,
        deliveredAt: _clock(),
        signaturePath: signaturePath,
        photoPath: photoPath,
        location: location,
        status: DeliveryRecordStatus.queued,
      );
      await _records.save(record);
      await _outbox.enqueue(
        type: deliveryOutboxType,
        payload: {'deliveryId': order.deliveryId},
        id: 'delivery-${order.deliveryId}',
      );
      return Right(record);
    } on Exception catch (error) {
      return Left(UnexpectedFailure('$error'));
    }
  }

  /// Asks the backend whether the hash is already anchored on Blockchain.
  Future<Either<Failure, DeliveryRecord>> refreshIntegrity(
    String deliveryId,
  ) async {
    final record = await _records.find(deliveryId);
    if (record == null) return const Left(NotFoundFailure());
    if (record.status == DeliveryRecordStatus.queued ||
        record.status == DeliveryRecordStatus.rejected) {
      return Right(record);
    }
    final result = await _gateway.integrity(deliveryId);
    switch (result) {
      case Left(:final value):
        return Left(value);
      case Right(:final value):
        final updated = record.withIntegrity(value);
        await _records.save(updated);
        return Right(updated);
    }
  }
}

/// Sends a queued delivery with its evidence. The backend computes the
/// SHA-256 without personal data and anchors it (TS-C02); the device never
/// talks to the Blockchain.
class DeliveryRegistrationHandler implements OutboxHandler {
  DeliveryRegistrationHandler(this._records, this._gateway, {this.onRejected});

  final DeliveryRecordRepository _records;
  final DeliveryGateway _gateway;

  /// The backend refused the delivery: its mission must be open again.
  final Future<void> Function(String deliveryId)? onRejected;

  @override
  String get type => deliveryOutboxType;

  @override
  Future<Either<Failure, Unit>> send(OutboxItem item) async {
    final record = await _records.find(item.payload['deliveryId']! as String);
    if (record == null) return const Right(unit);

    final result = await _gateway.register(record);
    switch (result) {
      case Right(:final value):
        await _records.save(record.withIntegrity(value));
        return const Right(unit);
      case Left(:final value) when !value.isRetryable:
        await _records.save(record.rejected(value.message));
        await onRejected?.call(record.deliveryId);
        return Left(value);
      case Left(:final value):
        return Left(value);
    }
  }
}
