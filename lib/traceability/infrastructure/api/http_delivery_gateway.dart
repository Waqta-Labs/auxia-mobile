import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../../../core/network/api_client.dart';
import '../../domain/model/delivery.dart';
import '../../domain/repositories/delivery_ports.dart';

/// [DeliveryGateway] over the Traceability endpoints of the backend.
class HttpDeliveryGateway implements DeliveryGateway {
  HttpDeliveryGateway(this._client, {this.readFile});

  final ApiClient _client;

  /// Builds the multipart file of an evidence (tests replace the disk).
  final Future<MultipartFile> Function(String path, DioMediaType type)?
  readFile;

  @override
  Future<Either<Failure, DeliveryIntegrity>> register(
    DeliveryRecord record,
  ) async {
    final FormData form;
    try {
      form = await registrationForm(record, readFile: readFile);
    } on Exception catch (error) {
      return Left(UnexpectedFailure('Evidence not readable: $error'));
    }
    return _client.postMultipart(
      '/deliveries/${record.deliveryId}/registration',
      form: form,
      parse: (data) => integrityFromJson(data! as Map<String, Object?>),
    );
  }

  @override
  Future<Either<Failure, DeliveryIntegrity>> integrity(String deliveryId) =>
      _client.get(
        '/deliveries/$deliveryId',
        parse: (data) => integrityFromJson(data! as Map<String, Object?>),
      );
}

/// Body of `POST /deliveries/{id}/registration`: the `delivery` part as JSON
/// with its own content type (without it the API answers 415) and the
/// signature and photo as `evidences`.
Future<FormData> registrationForm(
  DeliveryRecord record, {
  Future<MultipartFile> Function(String path, DioMediaType type)? readFile,
}) async {
  final read =
      readFile ??
      (path, type) => MultipartFile.fromFile(path, contentType: type);
  return FormData()
    ..files.addAll([
      MapEntry(
        'delivery',
        MultipartFile.fromString(
          jsonEncode(registrationJson(record)),
          contentType: DioMediaType('application', 'json'),
        ),
      ),
      MapEntry(
        'evidences',
        await read(record.signaturePath, DioMediaType('image', 'png')),
      ),
      MapEntry(
        'evidences',
        await read(record.photoPath, _imageType(record.photoPath)),
      ),
    ]);
}

Map<String, Object?> registrationJson(DeliveryRecord record) => {
  'deliveredAt': record.deliveredAt.toUtc().toIso8601String().substring(0, 19),
  'items': [
    for (final line in record.order.lines)
      if (line.delivered > 0)
        {'resourceId': line.resourceId, 'quantity': line.delivered},
  ],
  'location': ?record.location?.toJson(),
};

DioMediaType _imageType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return DioMediaType('image', 'png');
  if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
  if (lower.endsWith('.heic')) return DioMediaType('image', 'heic');
  return DioMediaType('image', 'jpeg');
}

/// Reads the `integrity` of a `DeliveryResource`.
DeliveryIntegrity integrityFromJson(Map<String, Object?> json) {
  final integrity = json['integrity'] as Map<String, Object?>? ?? const {};
  final anchoredAt = integrity['anchoredAt'] as String?;
  return DeliveryIntegrity(
    anchorStatus: switch (integrity['anchorStatus']) {
      'ANCHORED' => AnchorStatus.anchored,
      'FAILED' => AnchorStatus.failed,
      _ => AnchorStatus.pending,
    },
    recordHash: integrity['recordHash'] as String?,
    transactionHash: integrity['transactionHash'] as String?,
    anchoredAt: anchoredAt == null
        ? null
        : DateTime.parse(
            anchoredAt.endsWith('Z') ? anchoredAt : '${anchoredAt}Z',
          ),
  );
}
