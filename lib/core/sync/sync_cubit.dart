import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'sync_engine.dart';

/// Exposes the [SyncController] to the widgets: connectivity badges, the sync
/// progress bar and the "Sincronizar ahora" / "Forzar reintento" buttons.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit(this._engine) : super(_engine.state) {
    _subscription = _engine.states.listen(emit);
  }

  final SyncController _engine;
  late final StreamSubscription<SyncState> _subscription;

  Future<void> syncNow() => _engine.syncNow();

  Future<void> retryAll() => _engine.retryAll();

  void sessionRestored() => _engine.sessionRestored();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
