import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/sync/connectivity_monitor.dart';
import 'package:omnilife/core/sync/remote_writer.dart';
import 'package:omnilife/core/sync/sync_engine.dart';
import 'package:omnilife/core/sync/sync_operation.dart';
import 'package:omnilife/core/sync/sync_outbox.dart';
import 'package:omnilife/data/datasources/local/local_life_event_data_source.dart';
import 'package:omnilife/data/datasources/remote/life_event_remote_data_source.dart';
import 'package:omnilife/data/models/life_event_model.dart';
import 'package:omnilife/data/repositories/life_event_repository_impl.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _RecordingWriter implements RemoteWriter {
  final applied = <SyncOperation>[];

  @override
  Future<RemoteWriteResult> apply(SyncOperation op) async {
    applied.add(op);
    return RemoteWriteResult.applied;
  }
}

class _FakeRemote implements LifeEventRemoteDataSource {
  final docs = <LifeEventModel>[];
  bool offline = false;

  @override
  Future<List<LifeEventModel>> range(
    String uid,
    DateTime from,
    DateTime to,
  ) async {
    if (offline) throw Exception('offline');
    return docs
        .where(
          (m) =>
              m.event.uid == uid &&
              !m.event.timestamp.isBefore(from) &&
              m.event.timestamp.isBefore(to),
        )
        .toList();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late MemorySyncOutbox outbox;
  late _RecordingWriter writer;
  late FakeConnectivityMonitor connectivity;
  late SyncEngine sync;
  late _FakeRemote remote;
  late DateTime clock;
  var ids = 0;

  LifeEventRepositoryImpl build({bool useLocalDb = true}) =>
      LifeEventRepositoryImpl(
        sync: sync,
        local: LocalLifeEventDataSource(databaseProvider: () async => db),
        remote: remote,
        useLocalDb: useLocalDb,
        now: () => clock,
        newId: () => 'id${++ids}',
      );

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    outbox = MemorySyncOutbox();
    writer = _RecordingWriter();
    connectivity = FakeConnectivityMonitor(online: false);
    clock = DateTime(2026, 3, 2, 9);
    ids = 0;
    sync = SyncEngine(
      outbox: outbox,
      remote: writer,
      connectivity: connectivity,
      now: () => clock,
    );
    remote = _FakeRemote();
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  test('record stores locally, returns instantly and queues a sync', () async {
    final repo = build();

    final e = await repo.record(
      'u1',
      LifeEventType.water,
      metadata: {'ml': 250},
    );

    final stored = await repo.range(
      'u1',
      DateTime(2026, 3, 2),
      DateTime(2026, 3, 3),
    );
    expect(stored.single.id, e.id);
    expect(stored.single.metadata['ml'], 250);

    final queued = (await outbox.all()).single;
    expect(queued.collection, 'life_events');
    expect(queued.docId, e.id);
    expect(queued.data!['type'], 'water');
    expect(queued.data!['deleted'], false);
  });

  test('works fully offline and uploads once the network returns', () async {
    final repo = build();
    await repo.record('u1', LifeEventType.mood, metadata: {'score': 4});
    expect(writer.applied, isEmpty);

    connectivity.setOnline(true);
    await sync.flush();

    expect(writer.applied, hasLength(1));
    expect(await outbox.all(), isEmpty);
  });

  test('range is limited to the user and the requested window', () async {
    final repo = build();
    await repo.record('u1', LifeEventType.meal, at: DateTime(2026, 3, 2, 8));
    await repo.record('u1', LifeEventType.meal, at: DateTime(2026, 3, 3, 8));
    await repo.record('u2', LifeEventType.meal, at: DateTime(2026, 3, 2, 8));

    final got = await repo.range(
      'u1',
      DateTime(2026, 3, 2),
      DateTime(2026, 3, 3),
    );

    expect(got, hasLength(1));
    expect(got.single.uid, 'u1');
  });

  test('update changes the time, bumps updatedAt and re-queues', () async {
    final repo = build();
    final e = await repo.record('u1', LifeEventType.wake);

    clock = clock.add(const Duration(minutes: 5));
    final fixed = await repo.update(
      e.copyWith(timestamp: DateTime(2026, 3, 2, 7, 18)),
    );

    expect(fixed.timestamp, DateTime(2026, 3, 2, 7, 18));
    expect(fixed.updatedAt, clock);
    final queued = await outbox.all();
    expect(queued, hasLength(1)); // coalesced with the original create
    expect(
      queued.single.data!['timestamp'],
      fixed.timestamp.millisecondsSinceEpoch,
    );
  });

  test('delete hides the event locally and syncs a tombstone', () async {
    final repo = build();
    final e = await repo.record('u1', LifeEventType.water);

    clock = clock.add(const Duration(seconds: 3));
    await repo.delete(e);

    expect(
      await repo.range('u1', DateTime(2026, 3, 2), DateTime(2026, 3, 3)),
      isEmpty,
    );
    expect((await outbox.all()).single.data!['deleted'], true);
  });

  test(
    'refreshFromRemote merges newer remote events, never older ones',
    () async {
      final repo = build();
      final local = await repo.record(
        'u1',
        LifeEventType.mood,
        metadata: {'score': 2},
      );
      final changes = <void>[];
      final sub = repo.changes.listen(changes.add);

      final older = local.copyWith(
        metadata: {'score': 5},
        updatedAt: local.updatedAt.subtract(const Duration(hours: 1)),
      );
      final newerTime = LifeEvent(
        id: 'remote-1',
        uid: 'u1',
        type: LifeEventType.energy,
        timestamp: DateTime(2026, 3, 2, 10),
        createdAt: clock,
        updatedAt: clock,
        metadata: const {'level': 3},
      );
      remote.docs
        ..add(LifeEventModel(older))
        ..add(LifeEventModel(newerTime));

      await repo.refreshFromRemote('u1');
      await Future<void>.delayed(Duration.zero);

      final got = await repo.range(
        'u1',
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 3),
      );
      expect(got.map((e) => e.id), containsAll([local.id, 'remote-1']));
      expect(
        got.firstWhere((e) => e.id == local.id).moodScore,
        2,
      ); // not clobbered
      expect(changes, isNotEmpty);
      await sub.cancel();
    },
  );

  test('a remote tombstone removes the event locally', () async {
    final repo = build();
    final e = await repo.record('u1', LifeEventType.water);
    remote.docs.add(
      LifeEventModel(
        e.copyWith(updatedAt: clock.add(const Duration(hours: 1))),
        deleted: true,
      ),
    );

    await repo.refreshFromRemote('u1');

    expect(
      await repo.range('u1', DateTime(2026, 3, 2), DateTime(2026, 3, 3)),
      isEmpty,
    );
  });

  group('web mode (no SQLite)', () {
    test('merges remote, pending and session writes by updatedAt', () async {
      final repo = build(useLocalDb: false);
      final mine = await repo.record(
        'u1',
        LifeEventType.meal,
        at: DateTime(2026, 3, 2, 8),
      );
      remote.docs.add(
        LifeEventModel(
          LifeEvent(
            id: 'other-device',
            uid: 'u1',
            type: LifeEventType.workout,
            timestamp: DateTime(2026, 3, 2, 7),
            createdAt: clock,
            updatedAt: clock,
          ),
        ),
      );

      final got = await repo.range(
        'u1',
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 3),
      );

      expect(got.map((e) => e.id), ['other-device', mine.id]); // chronological
    });

    test(
      'still shows this session\'s writes when Firestore is unreachable',
      () async {
        final repo = build(useLocalDb: false);
        remote.offline = true;
        final e = await repo.record('u1', LifeEventType.water);

        final got = await repo.range(
          'u1',
          DateTime(2026, 3, 2),
          DateTime(2026, 3, 3),
        );

        expect(got.single.id, e.id);
      },
    );
  });
}
