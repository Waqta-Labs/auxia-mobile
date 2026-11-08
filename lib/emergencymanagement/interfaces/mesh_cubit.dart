import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../application/mesh_service.dart';

/// Exposes Mesh to the screens: the channels of A_05 and the switch of
/// A_06 / A_09 (plan D5).
class MeshCubit extends Cubit<MeshState> {
  MeshCubit(this._controller) : super(_controller.state) {
    _subscription = _controller.states.listen(emit);
  }

  /// Mesh turned off, for screens shown without the radio (tests, previews).
  MeshCubit.off() : this(const _OffMesh());

  final MeshController _controller;
  late final StreamSubscription<MeshState> _subscription;

  Future<void> setEnabled(bool enabled) => _controller.setEnabled(enabled);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

class _OffMesh implements MeshController {
  const _OffMesh();

  @override
  MeshState get state => const MeshState();

  @override
  Stream<MeshState> get states => const Stream.empty();

  @override
  Future<void> setEnabled(bool enabled) async {}
}
