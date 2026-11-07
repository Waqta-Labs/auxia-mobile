import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../../core/sync/outbox_item.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/sync_engine.dart';
import '../domain/model/citizen_report.dart';
import '../domain/repositories/citizen_report_gateway.dart';
import '../domain/repositories/citizen_report_repository.dart';
import 'sos_service.dart';

/// Sends a queued SOS. It reads the report at send time, so a detail added
/// while it waited travels with it. The report shows "Transmitiendo…" while
/// it is sent and until the backend prioritizes it. Once the backend stores
/// it, its photo and audio are queued for upload.
class CitizenReportHandler implements OutboxHandler {
  CitizenReportHandler(this._reports, this._gateway, this._outbox);

  final CitizenReportRepository _reports;
  final CitizenReportGateway _gateway;
  final OutboxRepository _outbox;

  @override
  String get type => CitizenOutboxTypes.report;

  @override
  Future<Either<Failure, Unit>> send(OutboxItem item) async {
    final report = await _reports.find(item.payload['reportId']! as String);
    if (report == null) return const Right(unit);

    await _reports.save(report.withStatus(CitizenReportStatus.transmitting));
    final result = await _gateway.submit(report);
    final latest = await _reports.find(report.id) ?? report;
    await _reports.save(
      latest.withStatus(
        result.isRight()
            ? CitizenReportStatus.received
            : CitizenReportStatus.saved,
      ),
    );
    if (result.isRight()) {
      await CitizenEvidenceQueue(_outbox).enqueueFor(latest);
    }
    return result;
  }
}

/// Uploads the photo or the audio of a stored SOS. A file that is no longer
/// on the device has nothing to send and leaves the queue.
class CitizenEvidenceHandler implements OutboxHandler {
  CitizenEvidenceHandler(this._gateway, {Future<bool> Function(String)? exists})
    : _exists = exists ?? ((path) => File(path).exists());

  final CitizenReportGateway _gateway;
  final Future<bool> Function(String path) _exists;

  @override
  String get type => CitizenOutboxTypes.evidence;

  @override
  Future<Either<Failure, Unit>> send(OutboxItem item) async {
    final path = item.payload['path']! as String;
    if (!await _exists(path)) return const Right(unit);
    return _gateway.uploadEvidence(
      item.payload['reportId']! as String,
      attachmentId: item.id,
      path: path,
    );
  }
}

/// Sends a detail added after its SOS already left the device.
class CitizenReportDetailHandler implements OutboxHandler {
  CitizenReportDetailHandler(this._reports, this._gateway);

  final CitizenReportRepository _reports;
  final CitizenReportGateway _gateway;

  @override
  String get type => CitizenOutboxTypes.detail;

  @override
  Future<Either<Failure, Unit>> send(OutboxItem item) async {
    final report = await _reports.find(item.payload['reportId']! as String);
    if (report == null) return const Right(unit);
    return _gateway.submit(
      report,
      clientReportId: item.id,
      text: report.toFollowUpText(),
      relatedReport: report,
    );
  }
}

/// Use cases of Mis reportes (A_05).
class MyReportsService {
  MyReportsService(this._reports, this._gateway);

  final CitizenReportRepository _reports;
  final CitizenReportGateway _gateway;

  Future<List<CitizenReport>> reports() => _reports.all();

  Stream<void> get changes => _reports.changes;

  /// Asks the backend how far each sent report got: prioritized by the AI
  /// (with its Urgency Score) or with a brigade on the way (with its ETA when
  /// known). A report the backend does not know is skipped. Without network
  /// nothing changes.
  Future<void> refreshStatuses() async {
    for (final report in await _reports.all()) {
      final followed =
          report.status == CitizenReportStatus.received ||
          report.status == CitizenReportStatus.prioritized ||
          report.status == CitizenReportStatus.brigadeOnTheWay;
      if (!followed) continue;

      final result = await _gateway.status(report.id);
      if (result case Left(value: NotFoundFailure())) continue;
      if (result case Right(value: final remote)) {
        if (remote.status.completedSteps < report.status.completedSteps) {
          continue;
        }
        await _reports.save(
          report.withStatus(
            remote.status,
            score: remote.score,
            etaMinutes: remote.etaMinutes,
          ),
        );
      } else {
        // Offline or the channel is not ready: try again later.
        return;
      }
    }
  }
}
