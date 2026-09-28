import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/errors/failures.dart';
import 'package:omnilife/data/datasources/local/app_database.dart';
import 'package:omnilife/data/datasources/local/local_task_data_source.dart';
import 'package:omnilife/data/repositories/task_repository_impl.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Task _newTask(String id, {String userId = 'u1', bool completed = false}) {
  final now = DateTime(2026, 1, 1, 9);
  return Task(
    id: id,
    userId: userId,
    title: 'Task $id',
    completed: completed,
    priority: TaskPriority.medium,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late TaskRepositoryImpl repository;

  setUp(() async {
    // A fresh in-memory database per test — no real device/emulator and
    // no shared state between tests.
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    );
    repository = TaskRepositoryImpl(
      dataSource: LocalTaskDataSource(databaseProvider: () async => db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('createTask then getTasks returns it for that user', () async {
    await repository.createTask(_newTask('t1'));

    final tasks = await repository.getTasks('u1');

    expect(tasks, hasLength(1));
    expect(tasks.first.id, 't1');
  });

  test('getTasks only returns tasks for the given user', () async {
    await repository.createTask(_newTask('t1', userId: 'u1'));
    await repository.createTask(_newTask('t2', userId: 'u2'));

    final tasksForU1 = await repository.getTasks('u1');

    expect(tasksForU1, hasLength(1));
    expect(tasksForU1.first.id, 't1');
  });

  test('getTask returns a single task by id, or null', () async {
    await repository.createTask(_newTask('t1'));

    final found = await repository.getTask('t1');
    final missing = await repository.getTask('nope');

    expect(found?.id, 't1');
    expect(missing, isNull);
  });

  test('updateTask persists changes and bumps updatedAt', () async {
    final created = await repository.createTask(_newTask('t1'));

    final updated = await repository.updateTask(
      created.copyWith(title: 'Renamed'),
    );

    expect(updated.title, 'Renamed');
    expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);

    final reloaded = await repository.getTask('t1');
    expect(reloaded?.title, 'Renamed');
  });

  test('updateTask on a missing id throws a DatabaseFailure', () async {
    expect(
      () => repository.updateTask(_newTask('missing')),
      throwsA(isA<DatabaseFailure>()),
    );
  });

  test('deleteTask removes the task', () async {
    await repository.createTask(_newTask('t1'));

    await repository.deleteTask('t1');

    expect(await repository.getTask('t1'), isNull);
  });

  test('deleteTask on a missing id throws a DatabaseFailure', () async {
    expect(
      () => repository.deleteTask('missing'),
      throwsA(isA<DatabaseFailure>()),
    );
  });

  test('completeTask marks the task completed', () async {
    await repository.createTask(_newTask('t1'));

    final completed = await repository.completeTask('t1');

    expect(completed.completed, isTrue);

    final reloaded = await repository.getTask('t1');
    expect(reloaded?.completed, isTrue);
  });

  test('completeTask on a missing id throws a DatabaseFailure', () async {
    expect(
      () => repository.completeTask('missing'),
      throwsA(isA<DatabaseFailure>()),
    );
  });
}
