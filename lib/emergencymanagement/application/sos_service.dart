import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../core/failure.dart';
import '../../core/sync/outbox_repository.dart';
import '../../shared/domain/geo_point.dart';
import '../domain/model/citizen_report.dart';
import '../domain/repositories/citizen_report_repository.dart';

/// Outbox types of the citizen reports.
abstract final class CitizenOutboxTypes {
  /// The SOS report itself.
  static const String report = 'citizen_report';

  /// A detail added after the SOS already left the device.
  static const String detail = 'citizen_report_detail';
}

/// Use cases of the one-tap SOS (A_03) and its optional detail (A_04).
class SosService {
  SosService(
    this._reports,
    this._outbox, {
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final CitizenReportRepository _reports;
  final OutboxRepository _outbox;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// SOS reports still waiting on the device ("3 reportes en cola").
  Future<int> queuedReports() =>
      _outbox.countUnsent(type: CitizenOutboxTypes.report);

  /// Fires when the queue changes.
  Stream<void> get queueChanges => _outbox.changes;

  /// Saves the SOS on the device and queues it. It never waits for the
  /// network or for a new GPS fix, so help is asked in under two seconds.
  Future<Either<Failure, CitizenReport>> sendSos({
    required HelpCategory category,
    GeoPoint? location,
  }) => _guard(() async {
    final report = CitizenReport(
      id: _uuid.v4(),
      code: await _reports.nextCode(),
      category: category,
      reportedAt: _clock(),
      status: CitizenReportStatus.saved,
      location: location,
    );
    await _reports.save(report);
    await _outbox.enqueue(
      type: CitizenOutboxTypes.report,
      payload: {'reportId': report.id},
      id: report.id,
    );
    return report;
  });

  /// Adds the GPS fix that arrived after the SOS, while it is still unsent.
  Future<Either<Failure, Unit>> attachLocation(
    String reportId,
    GeoPoint location,
  ) => _guard(() async {
    final report = await _reports.find(reportId);
    if (report != null && report.isUnsent && report.location == null) {
      await _reports.save(report.withLocation(location));
    }
    return unit;
  });

  /// "Guardar y Enviar Auxilio" (A_04). If the SOS is still on the device,
  /// the detail travels with it; if it already left, the detail follows as
  /// a second report that names the first one.
  Future<Either<Failure, CitizenReport>> addDetail(
    String reportId,
    EmergencyDetail detail,
  ) => _guard(() async {
    final report = await _reports.find(reportId);
    if (report == null) throw StateError('Unknown report $reportId');
    final updated = report.withDetail(detail);
    await _reports.save(updated);
    if (!report.isUnsent && !detail.isEmpty) {
      await _outbox.enqueue(
        type: CitizenOutboxTypes.detail,
        payload: {'reportId': report.id},
      );
    }
    return updated;
  });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on Exception catch (error) {
      return Left(UnexpectedFailure('$error'));
    } on StateError catch (error) {
      return Left(UnexpectedFailure(error.message));
    }
  }
}
