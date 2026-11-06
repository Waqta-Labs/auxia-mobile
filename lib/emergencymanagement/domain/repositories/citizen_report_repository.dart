import '../model/citizen_report.dart';

/// Port to the citizen reports kept on the device.
abstract interface class CitizenReportRepository {
  Future<void> save(CitizenReport report);

  Future<CitizenReport?> find(String id);

  /// Reports of the device, newest first.
  Future<List<CitizenReport>> all();

  /// Next short code, such as SR-0001.
  Future<String> nextCode();

  /// Fires after every write, so the screens refresh.
  Stream<void> get changes;
}
