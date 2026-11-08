import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/citizen_report_sync.dart';
import '../../../domain/model/citizen_report.dart';

class MyReportsState extends Equatable {
  const MyReportsState({
    this.reports = const [],
    this.issues = const {},
    this.loading = true,
  });

  final List<CitizenReport> reports;

  /// Saved reports that are retrying or failed, by report id.
  final Map<String, SendIssue> issues;
  final bool loading;

  @override
  List<Object> get props => [reports, issues, loading];
}

/// Mis reportes (A_05): the local queue and the status of each report.
///
/// The status of the sent reports is asked to the backend when the screen
/// starts, as soon as a report is received by the backend, and then every
/// [pollEvery] while there are sent reports: a brigade on the way can still
/// deliver and put the report back to prioritized.
class MyReportsCubit extends Cubit<MyReportsState> {
  MyReportsCubit(this._service, {this.pollEvery = const Duration(minutes: 1)})
    : super(const MyReportsState());

  final MyReportsService _service;

  /// Interval of the status polling; null turns it off.
  final Duration? pollEvery;

  StreamSubscription<void>? _subscription;
  Timer? _poll;
  bool _started = false;
  Set<String> _followed = const {};
  Future<void>? _refreshing;
  bool _refreshAgain = false;

  Future<void> start() async {
    _subscription = _service.changes.listen((_) => unawaited(_load()));
    await _load();
    await refreshStatuses();
    _started = true;
    final every = pollEvery;
    if (every != null && !isClosed) {
      _poll = Timer.periodic(every, (_) {
        if (_followed.isNotEmpty) unawaited(refreshStatuses());
      });
    }
  }

  /// Asks the backend for the status of the sent reports. A call made while
  /// another is running is merged into one more pass after it.
  Future<void> refreshStatuses() async {
    if (_refreshing case final running?) {
      _refreshAgain = true;
      return running;
    }
    final pass = _refreshPasses();
    _refreshing = pass;
    try {
      await pass;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _refreshPasses() async {
    do {
      _refreshAgain = false;
      await _service.refreshStatuses();
      await _load();
    } while (_refreshAgain && !isClosed);
  }

  Future<void> _load() async {
    final reports = await _service.reports();
    final issues = await _service.sendIssues(reports);
    if (isClosed) return;
    emit(MyReportsState(reports: reports, issues: issues, loading: false));

    final followed = {
      for (final report in reports)
        if (_waitingForBackend(report.status)) report.id,
    };
    final newlyReceived = followed.difference(_followed).isNotEmpty;
    _followed = followed;
    // Before [start] ends, its own first refresh covers every report.
    if (newlyReceived && _started) unawaited(refreshStatuses());
  }

  /// Sent reports whose status can still change on the backend.
  static bool _waitingForBackend(CitizenReportStatus status) =>
      status == CitizenReportStatus.received ||
      status == CitizenReportStatus.prioritized ||
      status == CitizenReportStatus.brigadeOnTheWay;

  @override
  Future<void> close() async {
    _poll?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
