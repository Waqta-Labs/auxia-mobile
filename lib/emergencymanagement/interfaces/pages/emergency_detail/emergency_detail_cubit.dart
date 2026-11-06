import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/quick_evidence.dart';
import '../../../application/sos_service.dart';
import '../../../domain/model/citizen_report.dart';

part 'emergency_detail_state.dart';

/// People counted on A_04.
enum PeopleGroup { children, elderly, injured }

/// Optional detail of an SOS (A_04).
class EmergencyDetailCubit extends Cubit<EmergencyDetailState> {
  EmergencyDetailCubit(
    this._service,
    this._evidence, {
    required this.reportId,
    this.maxAudio = const Duration(seconds: 5),
  }) : super(const EmergencyDetailState());

  final SosService _service;
  final QuickEvidence _evidence;
  final String reportId;

  /// Length of the quick audio (report 6.4.1: "grabación de audio de 5 s").
  final Duration maxAudio;
  Timer? _audioLimit;

  void increment(PeopleGroup group) => _changeCount(group, 1);

  void decrement(PeopleGroup group) => _changeCount(group, -1);

  void _changeCount(PeopleGroup group, int delta) {
    final detail = state.detail;
    int clamp(int value) => (value + delta).clamp(0, EmergencyDetail.maxPeople);
    emit(
      state.copyWith(
        detail: switch (group) {
          PeopleGroup.children => detail.copyWith(
            children: clamp(detail.children),
          ),
          PeopleGroup.elderly => detail.copyWith(
            elderly: clamp(detail.elderly),
          ),
          PeopleGroup.injured => detail.copyWith(
            injured: clamp(detail.injured),
          ),
        },
      ),
    );
  }

  void toggleCondition(AccessCondition condition) {
    final conditions = {...state.detail.accessConditions};
    if (!conditions.remove(condition)) conditions.add(condition);
    emit(
      state.copyWith(
        detail: state.detail.copyWith(accessConditions: conditions),
      ),
    );
  }

  /// "Mantén para grabar": records until released or for [maxAudio].
  Future<void> startAudio() async {
    if (state.recording) return;
    emit(state.copyWith(evidenceIssue: () => null));
    try {
      final started = await _evidence.startAudio();
      if (!started) {
        emit(state.copyWith(evidenceIssue: () => EvidenceIssue.microphone));
        return;
      }
    } on Exception {
      emit(state.copyWith(evidenceIssue: () => EvidenceIssue.microphone));
      return;
    }
    emit(state.copyWith(recording: true));
    _audioLimit = Timer(maxAudio, () => unawaited(stopAudio()));
  }

  Future<void> stopAudio() async {
    _audioLimit?.cancel();
    if (!state.recording) return;
    final path = await _evidence.stopAudio();
    if (isClosed) return;
    emit(
      state.copyWith(
        recording: false,
        detail: path == null
            ? state.detail
            : state.detail.copyWith(audioPath: () => path),
      ),
    );
  }

  Future<void> takePhoto() async {
    try {
      final path = await _evidence.takePhoto();
      if (path != null && !isClosed) {
        emit(
          state.copyWith(
            detail: state.detail.copyWith(photoPath: () => path),
            evidenceIssue: () => null,
          ),
        );
      }
    } on Exception {
      emit(state.copyWith(evidenceIssue: () => EvidenceIssue.camera));
    }
  }

  /// "Guardar y Enviar Auxilio".
  Future<void> submit() async {
    if (state.recording) await stopAudio();
    emit(state.copyWith(submitting: true, failed: false));
    final result = await _service.addDetail(reportId, state.detail);
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(submitting: false, failed: true)),
      (_) => emit(state.copyWith(submitting: false, submitted: true)),
    );
  }

  @override
  Future<void> close() {
    _audioLimit?.cancel();
    return super.close();
  }
}
