import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../../core/sync/outbox_item.dart';
import '../../core/sync/sync_engine.dart';
import '../domain/model/citizen_report.dart';
import '../domain/repositories/citizen_report_gateway.dart';
import '../domain/repositories/citizen_report_repository.dart';
import 'sos_service.dart';

/// Sends a queued SOS. It reads the report at send time, so a detail added
/// while it waited travels with it. The report shows "Transmitiendo" while
/// it is sent and "Recibido" once the backend accepts it.
class CitizenReportHandler implements OutboxHandler {
  CitizenReportHandler(this._reports, this._gateway);

  final CitizenReportRepository _reports;
  final CitizenReportGateway _gateway;

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
    return result;
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
  /// (with its Urgency Score) or with a brigade on the way (with its ETA).
  /// Without network nothing changes.
  Future<void> refreshStatuses() async {
    for (final report in await _reports.all()) {
      final followed =
          report.status == CitizenReportStatus.received ||
          report.status == CitizenReportStatus.prioritized ||
          report.status == CitizenReportStatus.brigadeOnTheWay;
      if (!followed) continue;

      final result = await _gateway.status(report.id);
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
