import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/sync/connectivity_monitor.dart';
import 'package:omnilife/core/sync/firestore_remote_writer.dart';
import 'package:omnilife/core/sync/key_value_store.dart';
import 'package:omnilife/core/sync/key_value_sync_outbox.dart';
import 'package:omnilife/core/sync/remote_writer.dart';
import 'package:omnilife/core/sync/sync_engine.dart';
import 'package:omnilife/core/sync/sync_operation.dart';
import 'package:omnilife/core/sync/sync_outbox.dart';

class FakeRemoteWriter implements RemoteWriter {
  final applied = <SyncOperation>[];
  final failuresToThrow = <Object>[];
  final remoteNewerDocs = <String>{};

  @override
  Future<RemoteWriteResult> apply(SyncOperation op) async {
    if (failuresToThrow.isNotEmpty) throw failuresToThrow.removeAt(0);
    if (remoteNewerDocs.contains(op.id)) {
      return RemoteWriteResult.skippedRemoteNewer;
    }
    applied.add(op);
    return RemoteWriteResult.applied;
  }
}

void main() {
  late MemorySyncOutbox outbox;
  late FakeRemoteWriter remote;
  late FakeConnectivityMonitor connectivity;
  late DateTime clock;
  late SyncEngine engine;

  setUp(() {
    outbox = MemorySyncOutbox();
    remote = FakeRemoteWriter();
    connectivity = FakeConnectivityMonitor(online: true);
    clock = DateTime(2026, 1, 1, 12);
    engine = SyncEngine(
      outbox: outbox,
      remote: remote,
      connectivity: connectivity,
      now: () => clock,
      random: Random(1),
      maxAttempts: 3,
    );
  });

  tearDown(() => engine.dispose());

  test('online write uploads once and the queue drains to synced', () async {
    await engine.enqueueSet('u1', 'tasks', 't1', {'title': 'A'});
    await engine.flush();

    expect(remote.applied, hasLength(1));
    expect(remote.applied.single.docId, 't1');
    expect(await outbox.all(), isEmpty);
    expect(engine.current.status, SyncStatus.synced);
  });

  test(
    'offline writes stay queued as offline, then flush on reconnect',
    () async {
      connectivity.setOnline(false);
      await engine.start();

      await engine.enqueueSet('u1', 'tasks', 't1', {'title': 'A'});
      await engine.flush();

      expect(remote.applied, isEmpty);
      expect(engine.current.status, SyncStatus.offline);
      expect(engine.current.pendingCount, 1);

      connectivity.setOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await engine.flush();

      expect(remote.applied, hasLength(1));
      expect(engine.current.status, SyncStatus.synced);
    },
  );

  test('repeated writes to one document coalesce to the newest', () async {
    connectivity.setOnline(false);
    await engine.enqueueSet('u1', 'tasks', 't1', {'title': 'v1'});
    await engine.enqueueSet('u1', 'tasks', 't1', {'title': 'v2'});
    expect((await outbox.all()), hasLength(1));

    connectivity.setOnline(true);
    await engine.flush();

    expect(remote.applied, hasLength(1));
    expect(remote.applied.single.data, {'title': 'v2'});
  });

  test('a delete after a set replaces it', () async {
    connectivity.setOnline(false);
    await engine.enqueueSet('u1', 'tasks', 't1', {'title': 'v1'});
    await engine.enqueueDelete('u1', 'tasks', 't1');

    connectivity.setOnline(true);
    await engine.flush();

    expect(remote.applied.single.type, SyncOpType.delete);
  });

  test(
    'failures back off exponentially and succeed on a later attempt',
    () async {
      remote.failuresToThrow.add(Exception('unavailable'));
      await engine.enqueueSet('u1', 'tasks', 't1', {'title': 'A'});
      await engine.flush();

      var op = (await outbox.get('tasks/t1'))!;
      expect(op.attempts, 1);
      expect(op.lastError, contains('unavailable'));
      expect(op.nextAttemptAtMs, greaterThan(clock.millisecondsSinceEpoch));
      expect(engine.current.status, SyncStatus.pending);

      // Not due yet: nothing happens.
      await engine.flush();
      expect(remote.applied, isEmpty);

      // After the backoff elapses it is retried and succeeds.
      clock = clock.add(const Duration(minutes: 1));
      await engine.flush();
      expect(remote.applied, hasLength(1));
      expect(await outbox.all(), isEmpty);
    },
  );

  test('backoff doubles per attempt and is capped', () {
    final deterministic = SyncEngine(
      outbox: outbox,
      remote: remote,
      connectivity: connectivity,
      now: () => clock,
      random: Random(7),
    );
    final d1 = deterministic.backoffFor(1).inMilliseconds;
    final d4 = deterministic.backoffFor(4).inMilliseconds;
    final d20 = deterministic.backoffFor(20).inMilliseconds;

    expect(d4, greaterThan(d1 * 4)); // roughly 8x within jitter bounds
    expect(d20, lessThanOrEqualTo((5 * 60 * 1000 * 1.2).round()));
    deterministic.dispose();
  });

  test(
    'operations fail permanently after maxAttempts and can be retried',
    () async {
      remote.failuresToThrow.addAll([
        Exception('e1'),
        Exception('e2'),
        Exception('e3'),
      ]);
      await engine.enqueueSet('u1', 'tasks', 't1', {'title': 'A'});
      for (var i = 0; i < 3; i++) {
        await engine.flush();
        clock = clock.add(const Duration(minutes: 10));
      }

      expect(engine.current.status, SyncStatus.failed);
      expect(engine.current.failedCount, 1);
      expect(remote.applied, isEmpty);

      await engine.retryFailed();

      expect(remote.applied, hasLength(1));
      expect(engine.current.status, SyncStatus.synced);
    },
  );

  test('a newer server copy wins and a conflict event is emitted', () async {
    remote.remoteNewerDocs.add('tasks/t1');
    final conflicts = <SyncConflict>[];
    final sub = engine.conflicts.listen(conflicts.add);

    await engine.enqueueSet('u1', 'tasks', 't1', {'title': 'stale'});
    await engine.flush();
    await Future<void>.delayed(Duration.zero);

    expect(remote.applied, isEmpty);
    expect(await outbox.all(), isEmpty);
    expect(conflicts.single.docId, 't1');
    await sub.cancel();
  });

  test(
    'overlay applies pending sets and deletes over remote documents',
    () async {
      connectivity.setOnline(false);
      await engine.enqueueSet('u1', 'tasks', 'new', {'title': 'local only'});
      await engine.enqueueSet('u1', 'tasks', 'a', {'title': 'edited'});
      await engine.enqueueDelete('u1', 'tasks', 'b');
      await engine.enqueueSet('u2', 'tasks', 'other-user', {'title': 'x'});

      final merged = await engine.overlay('u1', 'tasks', [
        {'id': 'a', 'title': 'orig', 'done': false},
        {'id': 'b', 'title': 'to delete'},
      ]);

      final byId = {for (final d in merged) d['id']: d};
      expect(byId.keys, unorderedEquals(['a', 'new']));
      expect(byId['a']!['title'], 'edited');
      expect(byId['a']!['done'], false);
    },
  );

  test('a write replaced during upload is not dropped', () async {
    final replacing = _ReplacingRemote(
      onApply: () => engine.enqueueSet('u1', 'tasks', 't1', {'title': 'v2'}),
    );
    final eng = SyncEngine(
      outbox: outbox,
      remote: replacing,
      connectivity: connectivity,
      now: () => clock, // identical timestamps for v1 and v2 on purpose
    );
    engine = eng;
    await eng.enqueueSet('u1', 'tasks', 't1', {'title': 'v1'});
    await eng.flush();

    expect(replacing.uploadedTitles, ['v1', 'v2']);
    expect(await outbox.all(), isEmpty);
  });

  test('only the signed-in users writes upload; others wait', () async {
    String? signedIn = 'u1';
    final eng = SyncEngine(
      outbox: outbox,
      remote: remote,
      connectivity: connectivity,
      now: () => clock,
      currentUid: () => signedIn,
    );
    engine = eng;
    await eng.enqueueSet('u1', 'tasks', 'mine', {'title': 'a'});
    await eng.enqueueSet('u2', 'tasks', 'theirs', {'title': 'b'});
    await eng.flush();

    expect(remote.applied.map((o) => o.docId), ['mine']);
    expect((await outbox.all()).single.uid, 'u2');

    signedIn = 'u2'; // the other account signs in on this device
    await eng.flush();
    expect(remote.applied.map((o) => o.docId), ['mine', 'theirs']);
    expect(await outbox.all(), isEmpty);
  });

  test('nothing uploads while signed out', () async {
    final eng = SyncEngine(
      outbox: outbox,
      remote: remote,
      connectivity: connectivity,
      now: () => clock,
      currentUid: () => null,
    );
    engine = eng;
    await eng.enqueueSet('u1', 'tasks', 't', {'title': 'a'});
    await eng.flush();
    expect(remote.applied, isEmpty);
    expect(await outbox.all(), hasLength(1));
  });

  group('persistence', () {
    test('KeyValueSyncOutbox survives re-instantiation', () async {
      final store = MemoryKeyValueStore();
      final a = KeyValueSyncOutbox(store);
      await a.upsert(
        const SyncOperation(
          uid: 'u1',
          collection: 'notes',
          docId: 'n1',
          type: SyncOpType.set,
          data: {'title': 'hello', 'n': 3},
          updatedAtMs: 10,
          createdAtMs: 5,
        ),
      );

      final b = KeyValueSyncOutbox(store);
      final restored = (await b.all()).single;

      expect(restored.id, 'notes/n1');
      expect(restored.data, {'title': 'hello', 'n': 3});
      expect(restored.state, SyncOpState.pending);
    });

    test('SyncOperation map round trip preserves retry state', () {
      const op = SyncOperation(
        uid: 'u',
        collection: 'c',
        docId: 'd',
        type: SyncOpType.delete,
        updatedAtMs: 1,
        createdAtMs: 2,
        attempts: 4,
        nextAttemptAtMs: 99,
        lastError: 'boom',
        state: SyncOpState.failed,
      );
      final copy = SyncOperation.fromMap(op.toMap());
      expect(copy.attempts, 4);
      expect(copy.nextAttemptAtMs, 99);
      expect(copy.lastError, 'boom');
      expect(copy.state, SyncOpState.failed);
      expect(copy.type, SyncOpType.delete);
    });
  });

  test('updatedAt parsing accepts ISO strings and epoch millis', () {
    expect(
      FirestoreRemoteWriter.parseUpdatedAtMs({
        'updatedAt': '2026-01-01T00:00:00.000Z',
      }),
      DateTime.utc(2026).millisecondsSinceEpoch,
    );
    expect(FirestoreRemoteWriter.parseUpdatedAtMs({'updatedAt': 42}), 42);
    expect(FirestoreRemoteWriter.parseUpdatedAtMs({'x': 1}), isNull);
  });
}

class _ReplacingRemote implements RemoteWriter {
  _ReplacingRemote({required this.onApply});

  final Future<void> Function() onApply;
  int calls = 0;
  final uploadedTitles = <String>[];

  @override
  Future<RemoteWriteResult> apply(SyncOperation op) async {
    calls++;
    uploadedTitles.add(op.data!['title'] as String);
    if (calls == 1) await onApply();
    return RemoteWriteResult.applied;
  }
}
