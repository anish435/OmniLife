import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/sync/sync_operation.dart';
import 'package:omnilife/data/datasources/local/app_database.dart';
import 'package:omnilife/data/datasources/local/local_calendar_data_source.dart';
import 'package:omnilife/data/datasources/local/local_finance_data_source.dart';
import 'package:omnilife/data/datasources/local/local_focus_data_source.dart';
import 'package:omnilife/data/datasources/local/local_goal_data_source.dart';
import 'package:omnilife/data/datasources/local/local_habit_data_source.dart';
import 'package:omnilife/data/datasources/local/local_note_data_source.dart';
import 'package:omnilife/data/datasources/local/local_task_data_source.dart';
import 'package:omnilife/data/datasources/local/local_wellness_data_source.dart';
import 'package:omnilife/data/datasources/local/saved_location_local_store.dart';
import 'package:omnilife/data/datasources/remote/user_scoped_firestore_datasource.dart';
import 'package:omnilife/data/models/finance_transaction_model.dart';
import 'package:omnilife/data/models/wellness_log_model.dart';
import 'package:omnilife/data/repositories/calendar_repository_impl.dart';
import 'package:omnilife/data/repositories/finance_repository_impl.dart';
import 'package:omnilife/data/repositories/focus_repository_impl.dart';
import 'package:omnilife/data/repositories/goal_repository_impl.dart';
import 'package:omnilife/data/repositories/habit_repository_impl.dart';
import 'package:omnilife/data/repositories/note_repository_impl.dart';
import 'package:omnilife/data/repositories/saved_location_repository_impl.dart';
import 'package:omnilife/data/repositories/task_repository_impl.dart';
import 'package:omnilife/data/repositories/wellness_repository_impl.dart';
import 'package:omnilife/domain/entities/calendar_event.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';
import 'package:omnilife/domain/entities/focus_session.dart';
import 'package:omnilife/domain/entities/goal.dart';
import 'package:omnilife/domain/entities/habit.dart';
import 'package:omnilife/domain/entities/note.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/entities/wellness_log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/location_sensor_fakes.dart' show place;
import '../../support/sync_fakes.dart';

/// Stands in for Firestore. Reads return [docs]; any write is a failure,
/// proving the repositories no longer write directly.
class _ReadOnlyRemote extends UserScopedFirestoreDataSource {
  final docs = <String, List<Map<String, dynamic>>>{};
  var directWrites = 0;

  @override
  Future<List<Map<String, dynamic>>> list(
    String uid,
    String collection,
  ) async => docs['$uid/$collection'] ?? const [];

  @override
  Future<void> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    directWrites++;
  }

  @override
  Future<void> delete(String uid, String collection, String docId) async {
    directWrites++;
  }
}

class _FakeFinanceLocal implements LocalFinanceDataSource {
  final rows = <String, FinanceTransactionModel>{};
  @override
  Future<void> insertTransaction(FinanceTransactionModel t) async =>
      rows[t.id] = t;
  @override
  Future<void> updateTransaction(FinanceTransactionModel t) async =>
      rows[t.id] = t;
  @override
  Future<void> deleteTransaction(String id) async => rows.remove(id);
  @override
  Future<List<FinanceTransactionModel>> getTransactions(
    String userId, {
    int? month,
    int? year,
  }) async => rows.values.where((e) => e.userId == userId).toList();
}

class _FakeWellnessLocal implements LocalWellnessDataSource {
  final rows = <String, WellnessLogModel>{};
  final synced = <String>{};
  @override
  Future<void> insertOrUpdateLog(WellnessLogModel log) async {
    rows[log.id] = log;
  }

  @override
  Future<void> markAsSynced(String id) async => synced.add(id);
  @override
  Future<List<WellnessLogModel>> getUnsyncedLogs(String userId) async => [
    for (final e in rows.values)
      if (!synced.contains(e.id)) e,
  ];
  @override
  Future<WellnessLogModel?> getLogForDate(String userId, DateTime d) async =>
      null;
  @override
  Future<List<WellnessLogModel>> getLogsForMonth(
    String userId,
    int year,
    int month,
  ) async => rows.values.toList();
}

final _t = DateTime(2026, 3, 1, 9);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late TestSync sync;
  late _ReadOnlyRemote remote;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, version) => AppDatabase.createSchema(db),
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    sync = TestSync(); // offline: operations wait in the outbox
    remote = _ReadOnlyRemote();
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  Future<SyncOperation> expectOp(
    String collection,
    String docId,
    SyncOpType type,
  ) async {
    final op = await sync.op(collection, docId);
    expect(
      op,
      isNotNull,
      reason: 'expected a queued op for $collection/$docId',
    );
    expect(op!.type, type);
    expect(op.uid, 'u1');
    expect(remote.directWrites, 0, reason: 'no direct Firestore write');
    return op;
  }

  group('tasks', () {
    late TaskRepositoryImpl repo;
    setUp(() {
      repo = TaskRepositoryImpl(
        dataSource: LocalTaskDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        syncEngine: sync.engine,
      );
    });

    test('create, update, complete and delete queue the right ops', () async {
      final task = Task(
        id: 't1',
        userId: 'u1',
        title: 'Pay rent',
        createdAt: _t,
        updatedAt: _t,
      );
      await repo.createTask(task);
      final created = await expectOp('tasks', 't1', SyncOpType.set);
      expect(created.data!['title'], 'Pay rent');

      await repo.updateTask(task.copyWith(title: 'Pay rent today'));
      final updated = await expectOp('tasks', 't1', SyncOpType.set);
      expect(updated.data!['title'], 'Pay rent today');
      expect(await sync.ops('tasks'), hasLength(1)); // coalesced

      await repo.completeTask('t1');
      expect(
        (await expectOp('tasks', 't1', SyncOpType.set)).data!['completed'],
        true,
      );

      await repo.deleteTask('t1');
      await expectOp('tasks', 't1', SyncOpType.delete);
    });

    test(
      'offline: local copy is kept and the op waits, then uploads',
      () async {
        await repo.createTask(
          Task(
            id: 't1',
            userId: 'u1',
            title: 'A',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
        expect((await repo.getTasks('u1')).map((t) => t.id), ['t1']);
        expect(sync.remote.applied, isEmpty);

        sync.connectivity.setOnline(true);
        await sync.engine.flush();
        expect(sync.remote.applied.single.docId, 't1');
        expect(await sync.ops('tasks'), isEmpty);
      },
    );

    test('guest user is never queued', () async {
      await repo.createTask(
        Task(
          id: 'g1',
          userId: 'guest-user',
          title: 'A',
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      expect(await sync.outbox.all(), isEmpty);
    });
  });

  group('calendar', () {
    test('create, update and delete queue ops', () async {
      final repo = CalendarRepositoryImpl(
        dataSource: LocalCalendarDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        syncEngine: sync.engine,
      );
      final e = CalendarEvent(
        id: 'e1',
        userId: 'u1',
        title: 'Dentist',
        startAt: _t,
        endAt: _t.add(const Duration(hours: 1)),
        createdAt: _t,
        updatedAt: _t,
      );
      await repo.createEvent(e);
      await expectOp('events', 'e1', SyncOpType.set);
      await repo.updateEvent(e.copyWith(title: 'Dentist 2'));
      expect(
        (await expectOp('events', 'e1', SyncOpType.set)).data!['title'],
        'Dentist 2',
      );
      await repo.deleteEvent('e1');
      await expectOp('events', 'e1', SyncOpType.delete);
    });
  });

  group('focus sessions', () {
    test('saveSession queues a set', () async {
      final repo = FocusRepositoryImpl(
        dataSource: LocalFocusDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        useLocalDatabase: true,
        syncEngine: sync.engine,
      );
      await repo.saveSession(
        FocusSession(
          id: 'f1',
          userId: 'u1',
          startedAt: _t,
          endedAt: _t.add(const Duration(minutes: 25)),
          plannedSeconds: 1500,
          focusedSeconds: 1500,
          completed: true,
        ),
      );
      final op = await expectOp('focus_sessions', 'f1', SyncOpType.set);
      expect(op.data!['focusedSeconds'], 1500);
    });
  });

  group('notes', () {
    test('create, archive-update and delete queue ops', () async {
      final repo = NoteRepositoryImpl(
        localDataSource: LocalNoteDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        syncEngine: sync.engine,
      );
      final n = Note(
        id: 'n1',
        userId: 'u1',
        title: 'Ideas',
        content: 'x',
        createdAt: _t,
        updatedAt: _t,
      );
      await repo.createNote(n);
      await expectOp('notes', 'n1', SyncOpType.set);
      await repo.updateNote(n.copyWith(isArchived: true));
      expect(
        (await expectOp('notes', 'n1', SyncOpType.set)).data!['isArchived'],
        true,
      );
      await repo.deleteNote('n1');
      await expectOp('notes', 'n1', SyncOpType.delete);
    });
  });

  group('habits and logs', () {
    late HabitRepositoryImpl repo;
    setUp(() {
      repo = HabitRepositoryImpl(
        localDataSource: LocalHabitDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        useLocalStorage: true,
        syncEngine: sync.engine,
      );
    });

    test('habit set, log toggle on/off, habit delete', () async {
      await repo.createHabit(
        Habit(
          id: 'h1',
          userId: 'u1',
          title: 'Read',
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      await expectOp('habits', 'h1', SyncOpType.set);

      await repo.toggleHabitLog('h1', '2026-03-10');
      final on = await expectOp(
        habitLogsCollection,
        'h1_2026-03-10',
        SyncOpType.set,
      );
      expect(on.data!['habitId'], 'h1');

      await repo.toggleHabitLog('h1', '2026-03-10');
      await expectOp(habitLogsCollection, 'h1_2026-03-10', SyncOpType.delete);

      await repo.deleteHabit('h1');
      await expectOp('habits', 'h1', SyncOpType.delete);
    });
  });

  group('goals', () {
    GoalRepositoryImpl build({required bool local}) => GoalRepositoryImpl(
      localDataSource: LocalGoalDataSource(databaseProvider: () async => db),
      remoteDataSource: remote,
      useLocalStorage: local,
      syncEngine: sync.engine,
    );

    Goal goal(String id) => Goal(
      id: id,
      userId: 'u1',
      title: 'Run 10k',
      createdAt: _t,
      updatedAt: _t,
    );

    test('create, update and delete queue ops', () async {
      final repo = build(local: true);
      await repo.createGoal(goal('g1'));
      await expectOp('goals', 'g1', SyncOpType.set);
      await repo.updateGoal(goal('g1').copyWith(title: 'Run 12k'));
      expect(
        (await expectOp('goals', 'g1', SyncOpType.set)).data!['title'],
        'Run 12k',
      );
      await repo.deleteGoal('g1');
      await expectOp('goals', 'g1', SyncOpType.delete);
    });

    test('web reads overlay queued writes, even after a restart', () async {
      final first = build(local: false);
      await first.createGoal(goal('g1'));
      // A brand new repository (as after a page refresh): the server list
      // is empty, but the outbox still holds the goal.
      final afterRefresh = build(local: false);
      expect((await afterRefresh.getGoals('u1')).map((g) => g.id), ['g1']);

      await afterRefresh.deleteGoal('g1');
      final again = build(local: false);
      expect(await again.getGoals('u1'), isEmpty);
    });
  });

  group('finance', () {
    test('create, update and delete queue ops', () async {
      final repo = FinanceRepositoryImpl(
        localDataSource: _FakeFinanceLocal(),
        remoteDataSource: remote,
        syncEngine: sync.engine,
      );
      final tx = FinanceTransaction(
        id: 'x1',
        userId: 'u1',
        amount: 12.5,
        title: 'Lunch',
        category: TransactionCategory.food,
        date: _t,
        createdAt: _t,
        updatedAt: _t,
      );
      await repo.createTransaction(tx);
      await expectOp('expenses', 'x1', SyncOpType.set);
      await repo.updateTransaction(tx.copyWith(title: 'Late lunch'));
      expect(
        (await expectOp('expenses', 'x1', SyncOpType.set)).data!['title'],
        'Late lunch',
      );
      await repo.deleteTransaction('x1');
      await expectOp('expenses', 'x1', SyncOpType.delete);
    });
  });

  group('wellness', () {
    test('saveLog queues a set and marks the local row handled', () async {
      final local = _FakeWellnessLocal();
      final repo = WellnessRepositoryImpl(
        local,
        remote,
        syncEngine: sync.engine,
      );
      await repo.saveLog(
        'u1',
        WellnessLog(id: '', date: DateTime(2026, 3, 1), waterIntakeMl: 500),
      );
      final op = await expectOp('wellness', 'u1_2026-03-01', SyncOpType.set);
      expect(op.data!['waterIntakeMl'], 500);
      expect(local.synced, contains('u1_2026-03-01'));
    });

    test('without a sync engine the row stays unsynced for a retry', () async {
      final local = _FakeWellnessLocal();
      final repo = WellnessRepositoryImpl(local, remote);
      await repo.saveLog(
        'u1',
        WellnessLog(id: '', date: DateTime(2026, 3, 1), waterIntakeMl: 500),
      );
      expect(local.synced, isEmpty);
    });
  });

  group('saved places', () {
    test('save and delete queue ops instead of writing directly', () async {
      final repo = SavedLocationRepositoryImpl(
        localStore: SqliteSavedLocationStore(databaseProvider: () async => db),
        syncEngine: sync.engine,
      );
      await SqliteSavedLocationStore.ensureSchema(db);
      await repo.save(place('a'));
      await repo.flush();
      final op = await expectOp('locations', 'a', SyncOpType.set);
      expect(op.data!['name'], 'Place a');
      // Durable in the outbox, so the local row is no longer pending.
      expect(await repo.syncPending('u1'), 0);

      await repo.delete('u1', 'a');
      await repo.flush();
      await expectOp('locations', 'a', SyncOpType.delete);
      expect(await repo.getLocations('u1'), isEmpty);
    });
  });
}
