import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/sync/connectivity_monitor.dart';
import 'package:omnilife/core/sync/remote_writer.dart';
import 'package:omnilife/core/sync/sync_engine.dart';
import 'package:omnilife/core/sync/sync_operation.dart';
import 'package:omnilife/core/sync/sync_outbox.dart';
import 'package:omnilife/data/datasources/local/local_reminder_data_source.dart';
import 'package:omnilife/data/datasources/remote/reminder_remote_data_source.dart';
import 'package:omnilife/data/models/reminder_model.dart';
import 'package:omnilife/data/repositories/reminder_repository_impl.dart';
import 'package:omnilife/domain/entities/reminder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _RecordingWriter extends RemoteWriter {
  final applied = <SyncOperation>[];

  @override
  Future<RemoteWriteResult> apply(SyncOperation op) async {
    applied.add(op);
    return RemoteWriteResult.applied;
  }
}

class _FakeRemote implements ReminderRemoteDataSource {
  final docs = <ReminderModel>[];
  bool offline = false;

  @override
  Future<List<ReminderModel>> list(String uid) async {
    if (offline) throw Exception('offline');
    return docs.where((m) => m.reminder.userId == uid).toList();
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

  ReminderRepositoryImpl build({bool useLocalDb = true}) =>
      ReminderRepositoryImpl(
        sync: sync,
        local: LocalReminderDataSource(databaseProvider: () async => db),
        remote: remote,
        useLocalDb: useLocalDb,
        now: () => clock,
      );

  Reminder reminder(String id, {String uid = 'u1', int hour = 9}) => Reminder(
    id: id,
    userId: uid,
    title: 'Reminder $id',
    scheduledAt: DateTime(2026, 3, 5, hour),
    createdAt: clock,
    updatedAt: clock,
  );

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    outbox = MemorySyncOutbox();
    writer = _RecordingWriter();
    connectivity = FakeConnectivityMonitor(online: false);
    clock = DateTime(2026, 3, 2, 9);
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

  test('create stores locally and queues users/{uid}/reminders/{id}', () async {
    final repo = build();
    await repo.create(reminder('a'));

    final listed = await repo.list('u1');
    expect(listed.single.id, 'a');

    final queued = (await outbox.all()).single;
    expect(queued.uid, 'u1');
    expect(queued.collection, 'reminders');
    expect(queued.docId, 'a');
    expect(queued.type, SyncOpType.set);
    expect(queued.data!['title'], 'Reminder a');
    expect(queued.data!['repeat'], 'none');
  });

  test('saved while offline, uploaded when the network returns', () async {
    final repo = build();
    await repo.create(reminder('a'));
    expect(writer.applied, isEmpty);

    connectivity.setOnline(true);
    await sync.flush();

    expect(writer.applied.single.docId, 'a');
    expect(await outbox.all(), isEmpty);
  });

  test('update bumps updatedAt and re-queues the same document', () async {
    final repo = build();
    final r = await repo.create(reminder('a'));
    clock = clock.add(const Duration(minutes: 5));

    final updated = await repo.update(r.copyWith(enabled: false));

    expect(updated.updatedAt, clock);
    expect((await repo.list('u1')).single.enabled, isFalse);
    final queued = await outbox.all();
    expect(queued, hasLength(1));
    expect(queued.single.data!['enabled'], false);
  });

  test('delete removes locally and queues a delete', () async {
    final repo = build();
    final r = await repo.create(reminder('a'));
    await repo.delete(r);

    expect(await repo.list('u1'), isEmpty);
    final queued = (await outbox.all()).single;
    expect(queued.type, SyncOpType.delete);
    expect(queued.docId, 'a');
  });

  test('list is limited to the user and sorted by time', () async {
    final repo = build();
    await repo.create(reminder('late', hour: 18));
    await repo.create(reminder('early', hour: 7));
    await repo.create(reminder('other', uid: 'u2'));

    expect((await repo.list('u1')).map((r) => r.id), ['early', 'late']);
  });

  test('table is created lazily on a fresh database', () async {
    final repo = build();
    expect(await repo.list('u1'), isEmpty);
  });

  test(
    'refreshFromRemote adds new docs but never overwrites queued ones',
    () async {
      final repo = build();
      await repo.create(reminder('mine'));
      remote.docs
        ..add(
          ReminderModel(
            reminder('mine').copyWith(
              title: 'Changed elsewhere',
              updatedAt: clock.add(const Duration(hours: 1)),
            ),
          ),
        )
        ..add(ReminderModel(reminder('theirs')));

      expect(await repo.refreshFromRemote('u1'), isTrue);

      final byId = {for (final r in await repo.list('u1')) r.id: r};
      expect(byId['theirs'], isNotNull);
      expect(byId['mine']!.title, 'Reminder mine');
    },
  );

  test(
    'web: merges remote, queued and session writes without sqlite',
    () async {
      remote.docs.add(ReminderModel(reminder('remote')));
      final repo = build(useLocalDb: false);
      await repo.create(reminder('new'));

      expect((await repo.list('u1')).map((r) => r.id).toSet(), {
        'remote',
        'new',
      });

      await repo.delete(reminder('remote'));
      expect((await repo.list('u1')).map((r) => r.id), ['new']);

      remote.offline = true;
      expect((await repo.list('u1')).map((r) => r.id), ['new']);
    },
  );
}
