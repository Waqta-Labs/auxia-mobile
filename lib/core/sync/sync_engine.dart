import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../connectivity/connectivity_monitor.dart';
import '../failure.dart';
import 'outbox_item.dart';
import 'outbox_repository.dart';

/// Sends the writes of one type of the outbox to the backend.
abstract interface class OutboxHandler {
  String get type;

  /// Sends the write. A retryable failure keeps it queued; any other failure
  /// rejects it.
  Future<Either<Failure, Unit>> send(OutboxItem item);
}

/// Waiting time before the next attempt: 5 s, 10 s, 20 s… up to 5 min.
Duration retryDelay(int attempts) {
  const base = Duration(seconds: 5);
  const cap = Duration(minutes: 5);
  final exponent = min(max(0, attempts - 1), 10);
  final delay = base * pow(2, exponent).toInt();
  return delay > cap ? cap : delay;
}

/// Progress of the synchronization, for the badges and the progress bar.
final class SyncState extends Equatable {
  const SyncState({
    this.network = const NetworkStatus.offline(),
    this.running = false,
    this.total = 0,
    this.done = 0,
    this.pending = 0,
    this.lastSyncAt,
    this.needsSignIn = false,
  });

  final NetworkStatus network;
  final bool running;

  /// Writes in the current run and how many were processed.
  final int total;
  final int done;

  /// Writes still waiting on the device.
  final int pending;

  /// Last run that reached the backend.
  final DateTime? lastSyncAt;

  /// The backend answered 401: the brigadist must sign in again.
  final bool needsSignIn;

  double? get progress => running && total > 0 ? done / total : null;

  SyncState copyWith({
    NetworkStatus? network,
    bool? running,
    int? total,
    int? done,
    int? pending,
    DateTime? lastSyncAt,
    bool? needsSignIn,
  }) => SyncState(
    network: network ?? this.network,
    running: running ?? this.running,
    total: total ?? this.total,
    done: done ?? this.done,
    pending: pending ?? this.pending,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    needsSignIn: needsSignIn ?? this.needsSignIn,
  );

  @override
  List<Object?> get props => [
    network,
    running,
    total,
    done,
    pending,
    lastSyncAt,
    needsSignIn,
  ];
}

/// What the interface can ask of the synchronization.
abstract interface class SyncController {
  SyncState get state;

  Stream<SyncState> get states;

  Future<void> syncNow();

  Future<void> retryAll();

  void sessionRestored();
}

/// Empties the outbox when there is network (TS-C06, R-02).
///
/// It runs when the network comes back, every minute while the app is open,
/// after each new write and when the user asks ("Forzar reintento",
/// "Sincronizar ahora").
class SyncEngine implements SyncController {
  SyncEngine({
    required this._outbox,
    required this._connectivity,
    required Iterable<OutboxHandler> handlers,
    DateTime Function()? clock,
    this.period = const Duration(minutes: 1),
  }) : _handlers = {for (final handler in handlers) handler.type: handler},
       _clock = clock ?? DateTime.now;

  final OutboxRepository _outbox;
  final ConnectivityMonitor _connectivity;
  final Map<String, OutboxHandler> _handlers;
  final DateTime Function() _clock;
  final Duration period;

  final StreamController<SyncState> _states = StreamController.broadcast();
  SyncState _state = const SyncState();
  StreamSubscription<NetworkStatus>? _networkSubscription;
  StreamSubscription<void>? _outboxSubscription;
  Timer? _timer;
  Future<void>? _running;

  @override
  SyncState get state => _state;

  @override
  Stream<SyncState> get states => _states.stream;

  /// Starts listening to the network and to new writes.
  Future<void> start() async {
    await _outbox.recoverInterrupted();
    _emit(
      _state.copyWith(
        network: await _connectivity.current(),
        pending: await _outbox.countUnsent(),
      ),
    );
    _networkSubscription = _connectivity.changes.listen((network) {
      final cameOnline = network.isOnline && !_state.network.isOnline;
      _emit(_state.copyWith(network: network));
      if (cameOnline) unawaited(syncNow());
    });
    _outboxSubscription = _outbox.changes.listen((_) {
      unawaited(_refreshPending());
      if (_state.network.isOnline) unawaited(syncNow());
    });
    _timer = Timer.periodic(period, (_) => unawaited(syncNow()));
    unawaited(syncNow());
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _networkSubscription?.cancel();
    await _outboxSubscription?.cancel();
  }

  /// "Forzar reintento de sincronización": every queued write is due now.
  @override
  Future<void> retryAll() async {
    await _outbox.makeAllDue();
    await syncNow();
  }

  /// Sends the due writes. Concurrent calls share the same run.
  @override
  Future<void> syncNow() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  /// The brigadist signed in again: queued writes can be retried.
  @override
  void sessionRestored() => _emit(_state.copyWith(needsSignIn: false));

  Future<void> _run() async {
    final network = await _connectivity.current();
    _emit(_state.copyWith(network: network));
    if (!network.isOnline) return;

    final due = await _outbox.due();
    if (due.isEmpty) return;

    _emit(_state.copyWith(running: true, total: due.length, done: 0));
    var reachedBackend = false;
    for (final item in due) {
      final outcome = await _send(item);
      if (outcome != _Outcome.offline) reachedBackend = true;
      _emit(_state.copyWith(done: _state.done + 1));
      if (outcome == _Outcome.offline || outcome == _Outcome.unauthorized) {
        break;
      }
    }
    _emit(
      _state.copyWith(
        running: false,
        pending: await _outbox.countUnsent(),
        lastSyncAt: reachedBackend ? _clock() : null,
      ),
    );
  }

  Future<_Outcome> _send(OutboxItem item) async {
    final handler = _handlers[item.type];
    if (handler == null) {
      // No channel can send this kind of write yet (for example, a backend
      // endpoint that is still missing). It stays on the device.
      await _retryLater(item, 'No channel for ${item.type} yet');
      return _Outcome.retry;
    }

    await _outbox.markSending(item.id);
    final Either<Failure, Unit> result;
    try {
      result = await handler.send(item);
    } on Exception catch (error) {
      await _retryLater(item, '$error');
      return _Outcome.retry;
    }

    switch (result) {
      case Right():
        await _outbox.markSent(item.id);
        return _Outcome.sent;
      case Left(value: final UnauthorizedFailure failure):
        await _retryLater(item, failure.message);
        _emit(_state.copyWith(needsSignIn: true));
        return _Outcome.unauthorized;
      case Left(value: final NetworkFailure failure):
        await _retryLater(item, failure.message);
        return _Outcome.offline;
      case Left(value: final failure) when failure.isRetryable:
        await _retryLater(item, failure.message);
        return _Outcome.retry;
      case Left(value: final failure):
        await _outbox.markRejected(item.id, failure.message);
        return _Outcome.rejected;
    }
  }

  Future<void> _retryLater(OutboxItem item, String error) {
    final attempts = item.attempts + 1;
    return _outbox.reschedule(
      item.id,
      attempts: attempts,
      nextAttemptAt: _clock().add(retryDelay(attempts)),
      error: error,
    );
  }

  Future<void> _refreshPending() async =>
      _emit(_state.copyWith(pending: await _outbox.countUnsent()));

  void _emit(SyncState state) {
    if (state == _state) return;
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }
}

enum _Outcome { sent, retry, rejected, offline, unauthorized }
