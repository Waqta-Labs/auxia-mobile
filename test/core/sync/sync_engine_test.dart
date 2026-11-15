import 'dart:async';

import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/core/sync/outbox_item.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/core/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

/// Handler that answers with the next queued result.
class _ScriptedHandler implements OutboxHandler {
  _ScriptedHandler(this.results);

  final List<Either<Failure, Unit>> results;
  final List<String> sent = [];

  @override
  String get type => 'citizen_report';

  @override
  Future<Either<Failure, Unit>> send(OutboxItem item) async {
    sent.add(item.id);
    return results.isEmpty ? const Right(unit) : results.removeAt(0);
  }
}

/// Handler that runs [onSend] for every write.
class _CallbackHandler implements OutboxHandler {
  _CallbackHandler(this.onSend);

  final Future<Either<Failure, Unit>> Function(OutboxItem item) onSend;
  final List<String> sent = [];

  @override
  String get type => 'citizen_report';

  @override
  Future<Either<Failure, Unit>> send(OutboxItem item) {
    sent.add(item.id);
    return onSend(item);
  }
}

void main() {
  late Database db;
  late DateTime now;
  late OutboxRepository outbox;
  late FakeConnectivityMonitor network;

  setUp(() async {
    db = await openTestDatabase();
    now = DateTime(2026, 11, 6, 9, 41);
    outbox = OutboxRepository(db, clock: () => now);
    network = FakeConnectivityMonitor();
  });

  tearDown(() => db.close());

  SyncEngine engine(_ScriptedHandler handler) => SyncEngine(
    outbox: outbox,
    connectivity: network,
    handlers: [handler],
    clock: () => now,
  );

  test('retry delay doubles from 5 s up to 5 min', () {
    expect(retryDelay(1), const Duration(seconds: 5));
    expect(retryDelay(2), const Duration(seconds: 10));
    expect(retryDelay(4), const Duration(seconds: 40));
    expect(retryDelay(20), const Duration(minutes: 5));
  });

  test('sends due writes and records the sync time', () async {
    final handler = _ScriptedHandler([]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'b');

    await sync.syncNow();

    expect(handler.sent, ['a', 'b']);
    expect((await outbox.find('a'))!.status, OutboxStatus.sent);
    expect(sync.state.pending, 0);
    expect(sync.state.lastSyncAt, now);
    expect(sync.state.running, isFalse);
  });

  test('keeps everything on the device without network', () async {
    network.set(online: false);
    final handler = _ScriptedHandler([]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');

    await sync.syncNow();

    expect(handler.sent, isEmpty);
    expect((await outbox.find('a'))!.status, OutboxStatus.pending);
  });

  test('a server error is retried later with backoff', () async {
    final handler = _ScriptedHandler([const Left(ServerFailure('down'))]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');

    await sync.syncNow();

    final item = (await outbox.find('a'))!;
    expect(item.status, OutboxStatus.pending);
    expect(item.attempts, 1);
    expect(item.nextAttemptAt, now.add(const Duration(seconds: 5)));

    await sync.syncNow();
    expect(handler.sent, ['a'], reason: 'not due yet');

    now = now.add(const Duration(seconds: 5));
    await sync.syncNow();
    expect(handler.sent, ['a', 'a']);
    expect((await outbox.find('a'))!.status, OutboxStatus.sent);
  });

  test('a write queued during a run is sent in the same sync', () async {
    late SyncEngine sync;
    final handler = _CallbackHandler((item) async {
      if (item.id == 'a') {
        await outbox.enqueue(
          type: 'citizen_report',
          payload: const {},
          id: 'b',
        );
        // What the outbox listener does after every write.
        await Future<void>.delayed(Duration.zero);
        unawaited(sync.syncNow());
      }
      return const Right(unit);
    });
    sync = SyncEngine(
      outbox: outbox,
      connectivity: network,
      handlers: [handler],
      clock: () => now,
    );
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');

    await sync.syncNow();

    expect(handler.sent, ['a', 'b']);
    expect((await outbox.find('b'))!.status, OutboxStatus.sent);
  });

  test('a bug in a handler requeues the write and stops the bar', () async {
    final handler = _CallbackHandler((_) async => throw StateError('bug'));
    final sync = SyncEngine(
      outbox: outbox,
      connectivity: network,
      handlers: [handler],
      clock: () => now,
    );
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');

    await expectLater(sync.syncNow(), throwsStateError);

    final item = (await outbox.find('a'))!;
    expect(item.status, OutboxStatus.pending);
    expect(item.attempts, 1);
    expect(sync.state.running, isFalse);
  });

  test('a rejected write is not retried', () async {
    final handler = _ScriptedHandler([
      const Left(ValidationFailure('Quantity above the plan')),
    ]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');

    await sync.syncNow();

    final item = (await outbox.find('a'))!;
    expect(item.status, OutboxStatus.rejected);
    expect(item.lastError, 'Quantity above the plan');
  });

  test('an expired session stops the run and asks to sign in', () async {
    final handler = _ScriptedHandler([const Left(UnauthorizedFailure())]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'b');

    await sync.syncNow();

    expect(handler.sent, ['a']);
    expect(sync.state.needsSignIn, isTrue);
    expect(await outbox.countUnsent(), 2);

    sync.sessionRestored();
    expect(sync.state.needsSignIn, isFalse);
  });

  test('a lost connection stops the run without sync time', () async {
    final handler = _ScriptedHandler([const Left(NetworkFailure())]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'b');

    await sync.syncNow();

    expect(handler.sent, ['a']);
    expect(sync.state.lastSyncAt, isNull);
  });

  test('a write without a channel yet stays on the device', () async {
    final sync = engine(_ScriptedHandler([]));
    await outbox.enqueue(type: 'unknown', payload: const {}, id: 'x');

    await sync.syncNow();

    final item = (await outbox.find('x'))!;
    expect(item.status, OutboxStatus.pending);
    expect(item.attempts, 1);
  });

  test('forcing a retry sends writes that were waiting', () async {
    final handler = _ScriptedHandler([const Left(ServerFailure('down'))]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');
    await sync.syncNow();

    await sync.retryAll();

    expect(handler.sent, ['a', 'a']);
    expect((await outbox.find('a'))!.status, OutboxStatus.sent);
  });

  test('syncs when the network comes back', () async {
    network.set(online: false);
    final handler = _ScriptedHandler([]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');
    await sync.start();
    expect(handler.sent, isEmpty);

    network.set(online: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sync.syncNow();

    expect(handler.sent, ['a']);
    expect(sync.state.network.isOnline, isTrue);
    await sync.stop();
  });

  test(
    'the counter of pending writes does not undo the end of a run',
    () async {
      final handler = _ScriptedHandler([]);
      final sync = engine(handler);
      await sync.start();

      // Every write to the queue refreshes the counter while the run sends it.
      await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(handler.sent, ['a']);
      expect(sync.state.running, isFalse);
      expect(sync.state.lastSyncAt, now);
      expect(sync.state.pending, 0);
      await sync.stop();
    },
  );

  test('a write that failed without signal is retried soon', () async {
    final handler = _ScriptedHandler([
      const Left(NetworkFailure()),
      const Left(NetworkFailure()),
      const Left(NetworkFailure()),
      const Left(NetworkFailure()),
    ]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');

    late DateTime lastAttempt;
    for (var i = 0; i < 4; i++) {
      lastAttempt = now;
      await sync.syncNow();
      now = (await outbox.find('a'))!.nextAttemptAt;
    }

    // Losing the signal is not the fault of the backend: the wait does not
    // grow, so the report leaves soon after the signal is back (R-02).
    final item = (await outbox.find('a'))!;
    expect(item.attempts, 4);
    expect(item.nextAttemptAt.difference(lastAttempt), offlineRetryDelay);
    expect(handler.sent, ['a', 'a', 'a', 'a']);
  });

  test('every waiting write is sent as soon as the network is back', () async {
    final handler = _ScriptedHandler([const Left(ServerFailure('down'))]);
    final sync = engine(handler);
    await outbox.enqueue(type: 'citizen_report', payload: const {}, id: 'a');
    await sync.syncNow();
    expect((await outbox.find('a'))!.nextAttemptAt, isNot(now));

    network.set(online: false);
    await sync.start();
    network.set(online: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(handler.sent, ['a', 'a']);
    expect((await outbox.find('a'))!.status, OutboxStatus.sent);
    await sync.stop();
  });
}
