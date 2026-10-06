import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/datasources/local/app_database.dart';
import 'package:omnilife/data/datasources/local/local_goal_data_source.dart';
import 'package:omnilife/data/datasources/local/local_habit_data_source.dart';
import 'package:omnilife/data/datasources/remote/user_scoped_firestore_datasource.dart';
import 'package:omnilife/data/models/goal_model.dart';
import 'package:omnilife/data/repositories/goal_repository_impl.dart';
import 'package:omnilife/data/repositories/habit_repository_impl.dart';
import 'package:omnilife/domain/entities/goal.dart';
import 'package:omnilife/domain/entities/habit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory stand-in for Firestore that records what would be synced.
class FakeRemote extends UserScopedFirestoreDataSource {
  final Map<String, Map<String, Map<String, dynamic>>> store = {};
  bool offline = false;

  Map<String, Map<String, dynamic>> col(String uid, String c) =>
      store.putIfAbsent('$uid/$c', () => {});

  @override
  Future<List<Map<String, dynamic>>> list(String uid, String collection) async {
    if (offline) return [];
    return [
      for (final e in col(uid, collection).entries) {'id': e.key, ...e.value},
    ];
  }

  @override
  Future<void> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (offline) throw Exception('offline');
    col(uid, collection)[docId] = data;
  }

  @override
  Future<void> delete(String uid, String collection, String docId) async {
    if (offline) throw Exception('offline');
    col(uid, collection).remove(docId);
  }
}

Habit habit(String id, {String userId = 'u1'}) {
  final t = DateTime(2026, 3, 1);
  return Habit(
    id: id,
    userId: userId,
    title: 'H $id',
    createdAt: t,
    updatedAt: t,
  );
}

Goal goal(String id, {String? habitId, String userId = 'u1'}) {
  final t = DateTime(2026, 3, 1);
  return Goal(
    id: id,
    userId: userId,
    title: 'G $id',
    targetDescription: 'ten km',
    targetDate: DateTime(2026, 9, 1),
    linkedHabitId: habitId,
    milestones: const [
      GoalMilestone(id: 'm1', title: '5k', done: true),
      GoalMilestone(id: 'm2', title: '8k'),
    ],
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, version) => AppDatabase.createSchema(db),
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  });

  tearDown(() => db.close());

  group('habit repository (SQLite)', () {
    late HabitRepositoryImpl repo;
    late FakeRemote remote;

    setUp(() {
      remote = FakeRemote();
      repo = HabitRepositoryImpl(
        localDataSource: LocalHabitDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        useLocalStorage: true,
      );
    });

    test('toggle creates then removes a log, one row per day', () async {
      await repo.createHabit(habit('h1'));
      final created = await repo.toggleHabitLog('h1', '2026-03-10');
      expect(created, isNotNull);
      expect((await repo.getHabitLogs('h1')).map((l) => l.date), [
        '2026-03-10',
      ]);
      expect(await repo.toggleHabitLog('h1', '2026-03-10'), isNull);
      expect(await repo.getHabitLogs('h1'), isEmpty);
      final rows = await db.query(AppDatabase.habitLogsTable);
      expect(rows, isEmpty);
    });

    test('logs come back newest first and are scoped per habit', () async {
      await repo.createHabit(habit('h1'));
      await repo.createHabit(habit('h2'));
      await repo.toggleHabitLog('h1', '2026-03-01');
      await repo.toggleHabitLog('h1', '2026-03-09');
      await repo.toggleHabitLog('h2', '2026-03-05');
      expect((await repo.getHabitLogs('h1')).map((l) => l.date), [
        '2026-03-09',
        '2026-03-01',
      ]);
      expect((await repo.getHabitLogs('h2')).length, 1);
    });

    test('deleting a habit deletes its logs locally and in sync', () async {
      await repo.createHabit(habit('h1'));
      await repo.toggleHabitLog('h1', '2026-03-09');
      expect(remote.col('u1', habitLogsCollection).keys, ['h1_2026-03-09']);
      await repo.deleteHabit('h1');
      expect(await db.query(AppDatabase.habitLogsTable), isEmpty);
      expect(await db.query(AppDatabase.habitsTable), isEmpty);
      expect(remote.col('u1', habitLogsCollection), isEmpty);
    });

    test('streak fields round-trip through update', () async {
      await repo.createHabit(habit('h1'));
      await repo.updateHabit(
        habit('h1').copyWith(currentStreak: 4, longestStreak: 9),
      );
      final h = (await repo.getHabits('u1')).single;
      expect((h.currentStreak, h.longestStreak), (4, 9));
    });

    test('remote failures never fail local writes', () async {
      remote.offline = true;
      await repo.createHabit(habit('h1'));
      await repo.toggleHabitLog('h1', '2026-03-09');
      expect((await repo.getHabitLogs('h1')).length, 1);
    });
  });

  group('habit repository (web mode: memory + Firestore)', () {
    test('logs persist in the cache and are re-read from Firestore', () async {
      final remote = FakeRemote();
      final repo = HabitRepositoryImpl(
        localDataSource: LocalHabitDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        useLocalStorage: false,
      );
      await repo.createHabit(habit('h1'));
      await repo.toggleHabitLog('h1', '2026-03-09');
      await repo.toggleHabitLog('h1', '2026-03-10');
      await repo.toggleHabitLog('h1', '2026-03-09'); // undo
      expect((await repo.getHabitLogs('h1')).map((l) => l.date), [
        '2026-03-10',
      ]);
      expect(remote.col('u1', habitLogsCollection).keys, ['h1_2026-03-10']);

      // A fresh instance (app restart) restores from Firestore.
      final fresh = HabitRepositoryImpl(
        localDataSource: LocalHabitDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        useLocalStorage: false,
      );
      final habits = await fresh.getHabits('u1');
      expect(habits.single.id, 'h1');
      expect((await fresh.getHabitLogs('h1')).map((l) => l.date), [
        '2026-03-10',
      ]);
    });

    test(
      'offline: habits created this session are not lost on reload',
      () async {
        final remote = FakeRemote()..offline = true;
        final repo = HabitRepositoryImpl(
          localDataSource: LocalHabitDataSource(
            databaseProvider: () async => db,
          ),
          remoteDataSource: remote,
          useLocalStorage: false,
        );
        await repo.createHabit(habit('h1'));
        expect((await repo.getHabits('u1')).single.id, 'h1');
      },
    );
  });

  group('goal repository', () {
    test('ensureSchema is idempotent and creates the table', () async {
      await LocalGoalDataSource.ensureSchema(db);
      await LocalGoalDataSource.ensureSchema(db);
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = '${LocalGoalDataSource.goalsTable}'",
      );
      expect(rows.length, 1);
    });

    test('works on a database that never had the goals table', () async {
      final remote = FakeRemote();
      final repo = GoalRepositoryImpl(
        localDataSource: LocalGoalDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        useLocalStorage: true,
      );
      await repo.createGoal(goal('g1', habitId: 'h1'));
      final loaded = (await repo.getGoals('u1')).single;
      expect(loaded.title, 'G g1');
      expect(loaded.targetDescription, 'ten km');
      expect(loaded.targetDate, DateTime(2026, 9, 1));
      expect(loaded.linkedHabitId, 'h1');
      expect(loaded.milestones.map((m) => (m.id, m.title, m.done)), [
        ('m1', '5k', true),
        ('m2', '8k', false),
      ]);
      expect(await repo.getGoals('other-user'), isEmpty);
    });

    test(
      'update and delete persist and sync to users/{uid}/goals/{id}',
      () async {
        final remote = FakeRemote();
        final repo = GoalRepositoryImpl(
          localDataSource: LocalGoalDataSource(
            databaseProvider: () async => db,
          ),
          remoteDataSource: remote,
          useLocalStorage: true,
        );
        await repo.createGoal(goal('g1'));
        expect(remote.col('u1', 'goals').keys, ['g1']);
        final doc = remote.col('u1', 'goals')['g1']!;
        expect(doc['title'], 'G g1');
        expect((doc['milestones'] as List).length, 2);

        await repo.updateGoal(
          goal('g1').copyWith(
            title: 'Renamed',
            clearTargetDate: true,
            milestones: [
              const GoalMilestone(id: 'm1', title: '5k', done: true),
            ],
          ),
        );
        final loaded = (await repo.getGoals('u1')).single;
        expect(loaded.title, 'Renamed');
        expect(loaded.targetDate, isNull);
        expect(loaded.milestones.length, 1);
        expect(remote.col('u1', 'goals')['g1']!['title'], 'Renamed');

        await repo.deleteGoal('g1');
        expect(await repo.getGoals('u1'), isEmpty);
        expect(remote.col('u1', 'goals'), isEmpty);
      },
    );

    test('web mode reads Firestore and keeps unsynced local goals', () async {
      final remote = FakeRemote();
      remote.col('u1', 'goals')['r1'] = GoalModel.fromEntity(goal('r1'))
          .toFirestoreMap();
      final repo = GoalRepositoryImpl(
        localDataSource: LocalGoalDataSource(databaseProvider: () async => db),
        remoteDataSource: remote,
        useLocalStorage: false,
      );
      remote.offline = true; // creation will not sync
      await repo.createGoal(goal('local'));
      remote.offline = false;
      final ids = (await repo.getGoals('u1')).map((g) => g.id).toSet();
      expect(ids, {'r1', 'local'});
    });

    test('model parses both SQLite and Firestore shapes', () {
      final fromSql = GoalModel.fromMap(
        GoalModel.fromEntity(goal('g')).toMap(),
      );
      final fs = GoalModel.fromEntity(goal('g')).toFirestoreMap();
      final fromFs = GoalModel.fromMap({'id': 'g', ...fs});
      expect(fromSql.props, goal('g').props);
      expect(fromFs.milestones, goal('g').milestones);
      expect(fromFs.linkedHabitId, isNull);
      // Garbage milestones do not crash parsing.
      final bad = GoalModel.fromMap({
        'id': 'x',
        'user_id': 'u',
        'title': 't',
        'milestones': 'not json',
        'created_at': 1,
        'updated_at': 1,
      });
      expect(bad.milestones, isEmpty);
    });
  });
}
