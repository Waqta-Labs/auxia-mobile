import 'package:equatable/equatable.dart';

/// Figures of the local database shown on A_06 / A_09.
final class StorageStats extends Equatable {
  const StorageStats({
    this.citizenReports = 0,
    this.pendingSync = 0,
    this.missions = 0,
    this.evidenceToUpload = 0,
    this.blockchainQueue = 0,
    this.databaseBytes = 0,
    this.intact = true,
  });

  /// "Reportes locales" (citizen).
  final int citizenReports;

  /// "Pendientes de sync": writes still in the outbox.
  final int pendingSync;

  /// "Misiones locales" (brigadist).
  final int missions;

  /// "Evidencias por subir": photos and signatures of queued deliveries.
  final int evidenceToUpload;

  /// "Tx Blockchain en cola": deliveries whose hash is not anchored yet.
  final int blockchainQueue;

  /// "Tamaño de BD".
  final int databaseBytes;

  /// "Integridad · Cifrada · OK".
  final bool intact;

  @override
  List<Object> get props => [
    citizenReports,
    pendingSync,
    missions,
    evidenceToUpload,
    blockchainQueue,
    databaseBytes,
    intact,
  ];
}

/// Port that reads the figures of the local database.
abstract interface class StorageStatsSource {
  Future<StorageStats> read();
}
