import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../model/delivery.dart';

/// Port to the deliveries registered from the device.
abstract interface class DeliveryRecordRepository {
  Future<void> save(DeliveryRecord record);

  Future<DeliveryRecord?> find(String deliveryId);

  /// Records, newest first.
  Future<List<DeliveryRecord>> all();

  Stream<void> get changes;
}

/// Port to the Traceability endpoints of the backend.
abstract interface class DeliveryGateway {
  /// `POST /deliveries/{id}/registration` with the evidence. Sending the same
  /// delivery twice is safe: the backend answers with it as it is.
  Future<Either<Failure, DeliveryIntegrity>> register(DeliveryRecord record);

  /// `GET /deliveries/{id}`: anchoring status and hashes.
  Future<Either<Failure, DeliveryIntegrity>> integrity(String deliveryId);
}
