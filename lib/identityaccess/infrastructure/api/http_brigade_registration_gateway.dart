import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/failure.dart';
import '../../../core/network/api_client.dart';
import '../../domain/model/brigade_credential.dart';
import '../../domain/repositories/brigade_registration_gateway.dart';

/// [BrigadeRegistrationGateway] over
/// `/api/v1/public/brigade-registrations/{registrationId}`.
class HttpBrigadeRegistrationGateway implements BrigadeRegistrationGateway {
  HttpBrigadeRegistrationGateway(this._client, {this.readFile});

  static const String path = '/public/brigade-registrations';

  final ApiClient _client;

  /// Builds the multipart file of the ID card (tests replace the disk).
  final Future<MultipartFile> Function(String path, DioMediaType type)?
  readFile;

  @override
  Future<Either<Failure, Unit>> submit(
    BrigadeCredential credential, {
    required String fullName,
    required String phone,
  }) async {
    final FormData form;
    try {
      form = await registrationForm(
        credential,
        fullName: fullName,
        phone: phone,
        readFile: readFile,
      );
    } on Exception catch (error) {
      return Left(UnexpectedFailure('ID card not readable: $error'));
    }
    return _client.putMultipart(
      '$path/${credential.registrationId}',
      form: form,
      parse: (_) => unit,
    );
  }

  @override
  Future<Either<Failure, RegistrationDecision>> status(
    BrigadeCredential credential,
  ) => _client.get(
    '$path/${credential.registrationId}',
    headers: {'X-Device-Secret': credential.deviceSecret},
    parse: (data) => decisionFromJson(data! as Map<String, Object?>),
  );
}

/// Body of the PUT: the `registration` part as JSON with its own content
/// type and the optional photo of the ID card as `idCard`.
Future<FormData> registrationForm(
  BrigadeCredential credential, {
  required String fullName,
  required String phone,
  Future<MultipartFile> Function(String path, DioMediaType type)? readFile,
}) async {
  final read =
      readFile ??
      (file, type) => MultipartFile.fromFile(file, contentType: type);
  final form = FormData()
    ..files.add(
      MapEntry(
        'registration',
        MultipartFile.fromString(
          jsonEncode({
            'fullName': fullName,
            'phone': phone,
            'organization': credential.organization.value,
            'brigadeCode': credential.brigadeCode.value,
            'deviceSecret': credential.deviceSecret,
          }),
          contentType: DioMediaType('application', 'json'),
        ),
      ),
    );
  final idCard = credential.idCardPhotoPath;
  if (idCard != null) {
    form.files.add(MapEntry('idCard', await read(idCard, _imageType(idCard))));
  }
  return form;
}

/// Maps `{ "status": "PENDING" | "APPROVED" | "REJECTED", "reason" }`.
RegistrationDecision decisionFromJson(Map<String, Object?> json) =>
    RegistrationDecision(switch (json['status']) {
      'APPROVED' => CredentialStatus.approved,
      'REJECTED' => CredentialStatus.rejected,
      _ => CredentialStatus.pendingApproval,
    }, reason: json['reason'] as String?);

DioMediaType _imageType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return DioMediaType('image', 'png');
  if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
  if (lower.endsWith('.heic')) return DioMediaType('image', 'heic');
  return DioMediaType('image', 'jpeg');
}
