import 'package:auxia_mobile/core/database/app_database.dart';
import 'package:auxia_mobile/core/sync/outbox_item.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../helpers/test_app.dart';

void main() {
  late Database db;
  late DateTime now;
  late OutboxRepository outbox;

  setUp(() async {
    db = await openTestDatabase();
    now = DateTime(2026, 11, 6, 9, 41);
    outbox = OutboxRepository(db, clock: () => now);
  });

  tearDown(() => db.close());

  test(
    'the schema is created with its migrations and passes the check',
    () async {
      final app = AppDatabase(db);

      expect(await app.isIntact(), isTrue);
      expect(await app.sizeInBytes(), greaterThan(0));
      expect(await db.getVersion(), AppDatabase.version);
    },
  );

  test('a new write is pending and due at once', () async {
    final item = await outbox.enqueue(
      type: 'citizen_report',
      payload: {'category': 'MEDICAL', 'children': 3},
      id: 'sr-0412',
    );

    expect(item.status, OutboxStatus.pending);
    expect(await outbox.find('sr-0412'), item);
    expect(await outbox.due(), [item]);
    expect(await outbox.countUnsent(), 1);
    expect(await outbox.countUnsent(type: 'delivery'), 0);
  });

  test('a rescheduled write waits for its next attempt', () async {
    await outbox.enqueue(type: 't', payload: const {}, id: 'a');

    await outbox.reschedule(
      'a',
      attempts: 1,
      nextAttemptAt: now.add(const Duration(seconds: 5)),
      error: 'timeout',
    );

    expect(await outbox.due(), isEmpty);
    now = now.add(const Duration(seconds: 5));
    final due = await outbox.due();
    expect(due.single.attempts, 1);
    expect(due.single.lastError, 'timeout');
  });

  test('forcing a retry makes every pending write due', () async {
    await outbox.enqueue(type: 't', payload: const {}, id: 'a');
    await outbox.reschedule(
      'a',
      attempts: 3,
      nextAttemptAt: now.add(const Duration(minutes: 5)),
    );

    await outbox.makeAllDue();

    expect(await outbox.due(), hasLength(1));
  });

  test('sent and rejected writes leave the queue', () async {
    await outbox.enqueue(type: 't', payload: const {}, id: 'a');
    await outbox.enqueue(type: 't', payload: const {}, id: 'b');

    await outbox.markSent('a');
    await outbox.markRejected('b', 'invalid');

    expect(await outbox.countUnsent(), 0);
    expect((await outbox.find('b'))!.status, OutboxStatus.rejected);
    expect((await outbox.find('b'))!.lastError, 'invalid');
  });

  test('a write interrupted while sending goes back to the queue', () async {
    await outbox.enqueue(type: 't', payload: const {}, id: 'a');
    await outbox.markSending('a');
    expect(await outbox.due(), isEmpty);

    await outbox.recoverInterrupted();

    expect(await outbox.due(), hasLength(1));
  });

  test('every write notifies the listeners', () async {
    final events = <void>[];
    final subscription = outbox.changes.listen(events.add);

    await outbox.enqueue(type: 't', payload: const {}, id: 'a');
    await outbox.markSent('a');
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(2));
    await subscription.cancel();
  });
}
