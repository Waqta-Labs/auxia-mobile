import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/citizen_report_sync.dart';
import '../../../domain/model/citizen_report.dart';

class MyReportsState extends Equatable {
  const MyReportsState({this.reports = const [], this.loading = true});

  final List<CitizenReport> reports;
  final bool loading;

  @override
  List<Object> get props => [reports, loading];
}

/// Mis reportes (A_05): the local queue and the status of each report.
class MyReportsCubit extends Cubit<MyReportsState> {
  MyReportsCubit(this._service) : super(const MyReportsState());

  final MyReportsService _service;
  StreamSubscription<void>? _subscription;

  Future<void> start() async {
    _subscription = _service.changes.listen((_) => unawaited(_load()));
    await _load();
    await refreshStatuses();
  }

  Future<void> refreshStatuses() async {
    await _service.refreshStatuses();
    await _load();
  }

  Future<void> _load() async {
    final reports = await _service.reports();
    if (!isClosed) emit(MyReportsState(reports: reports, loading: false));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
