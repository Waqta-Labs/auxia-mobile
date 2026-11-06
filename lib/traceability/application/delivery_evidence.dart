import 'dart:typed_data';

/// Port to save the evidence of a delivery on the device.
abstract interface class DeliveryEvidence {
  /// Photo of the reception; null if the brigadist cancelled.
  Future<String?> takePhoto();

  /// Stores the signature of the beneficiary (PNG) and returns its path.
  Future<String> saveSignature(Uint8List png);
}
