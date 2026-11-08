import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/location/location_service.dart';
import '../../../../shared/domain/geo_point.dart';
import '../../../application/delivery_evidence.dart';
import '../../../application/delivery_service.dart';
import '../../../domain/model/delivery.dart';

part 'delivery_state.dart';

/// Verificar entrega (A_08): scan, evidence, Blockchain. The steps are kept
/// apart so a delivery can never be confirmed without complete evidence.
class DeliveryCubit extends Cubit<DeliveryState> {
  DeliveryCubit(
    this._service,
    this._evidence,
    this._location, {
    required DeliveryOrder order,
    required this.onRegistered,
    this.pollEvery = const Duration(seconds: 10),
  }) : super(DeliveryState(order: order));

  final DeliveryService _service;
  final DeliveryEvidence _evidence;
  final LocationService _location;

  /// The mission is done on the device once the delivery is saved.
  final Future<void> Function(String deliveryId) onRegistered;
  final Duration pollEvery;

  StreamSubscription<void>? _changes;
  Timer? _poll;

  /// Resumes a delivery already registered from this device.
  Future<void> start() async {
    _changes = _service.changes.listen((_) => unawaited(_reload()));
    await _reload();
  }

  void scanned(String raw) {
    if (state.step != DeliveryStep.scan) return;
    final id = deliveryIdFromQr(raw);
    if (id != null && id == state.order.deliveryId.toLowerCase()) {
      emit(state.copyWith(step: DeliveryStep.evidence, wrongCode: false));
      unawaited(locate());
    } else {
      emit(state.copyWith(wrongCode: true));
    }
  }

  void rescan() => emit(state.copyWith(step: DeliveryStep.scan));

  /// The backend refused the delivery: back to its evidence, kept from the
  /// saved record, to correct it and register it again.
  void correct() {
    final record = state.record;
    if (record == null || record.status != DeliveryRecordStatus.rejected) {
      return;
    }
    emit(
      state.copyWith(
        step: DeliveryStep.evidence,
        order: record.order,
        signaturePath: () => record.signaturePath,
        photoPath: () => record.photoPath,
        record: () => null,
      ),
    );
    unawaited(locate());
  }

  /// Asks the GPS for the place of the delivery while the evidence is taken
  /// (US-15), so A_08 can say whether it has it before registering.
  Future<void> locate() async {
    if (state.locating) return;
    emit(state.copyWith(locating: true));
    final result = await _location.locate(timeout: const Duration(seconds: 15));
    if (isClosed) return;
    emit(
      state.copyWith(
        locating: false,
        location: result is LocationFix ? () => result.point : null,
      ),
    );
  }

  void changeQuantity(String resourceId, int delta) => emit(
    state.copyWith(
      order: DeliveryOrder(
        deliveryId: state.order.deliveryId,
        zoneName: state.order.zoneName,
        brigadeName: state.order.brigadeName,
        lines: [
          for (final line in state.order.lines)
            line.resourceId == resourceId
                ? line.withDelivered(line.delivered + delta)
                : line,
        ],
      ),
    ),
  );

  Future<void> signed(Uint8List png) async {
    final path = await _evidence.saveSignature(png);
    if (!isClosed) emit(state.copyWith(signaturePath: () => path));
  }

  Future<void> takePhoto() async {
    try {
      final path = await _evidence.takePhoto();
      if (path != null && !isClosed) {
        emit(state.copyWith(photoPath: () => path));
      }
    } on Exception {
      emit(state.copyWith(cameraFailed: true));
    }
  }

  /// "Registrar entrega": saves it with the time and place of the delivery
  /// and queues the registration.
  Future<void> submit() async {
    if (!state.evidenceComplete || state.submitting) return;
    emit(state.copyWith(submitting: true));
    var location = state.location;
    if (location == null) {
      final position = await _location.locate(
        timeout: const Duration(seconds: 5),
      );
      if (position is LocationFix) location = position.point;
    }
    final result = await _service.register(
      order: state.order,
      signaturePath: state.signaturePath!,
      photoPath: state.photoPath!,
      location: location,
    );
    if (isClosed) return;
    await result.fold(
      (failure) async => emit(state.copyWith(submitting: false)),
      (record) async {
        emit(
          state.copyWith(
            submitting: false,
            step: DeliveryStep.blockchain,
            record: () => record,
          ),
        );
        await onRegistered(record.deliveryId);
      },
    );
  }

  /// Asks the backend for the anchoring of the hash.
  Future<void> refresh() async {
    await _service.refreshIntegrity(state.order.deliveryId);
  }

  Future<void> _reload() async {
    final record = await _service.find(state.order.deliveryId);
    if (isClosed || record == null) return;
    // The brigadist is correcting a refused delivery.
    if (record.status == DeliveryRecordStatus.rejected &&
        state.step == DeliveryStep.evidence) {
      return;
    }
    emit(state.copyWith(step: DeliveryStep.blockchain, record: () => record));
    _schedulePolling(record);
  }

  void _schedulePolling(DeliveryRecord record) {
    final waiting = record.status == DeliveryRecordStatus.registered;
    if (waiting && _poll == null) {
      _poll = Timer.periodic(pollEvery, (_) => unawaited(refresh()));
    } else if (!waiting) {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  Future<void> close() async {
    _poll?.cancel();
    await _changes?.cancel();
    return super.close();
  }
}
