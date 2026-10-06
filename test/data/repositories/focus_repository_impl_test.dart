import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/datasources/local/local_focus_data_source.dart';
import 'package:omnilife/data/repositories/focus_repository_impl.dart';
import 'package:omnilife/domain/entities/focus_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

FocusSession _session(
  String id, {
  String userId = 'u1',
  DateTime? startedAt,
  int focusedSeconds = 1500,
}) {
  final start = startedAt ?? DateTime(2026, 10, 6, 9);
  return FocusSession(
    id: id,
    userId: userId,
    startedAt: start,
    endedAt: start.add(Duration(seconds: focusedSeconds)),
    plannedSeconds: 1500,
    focusedSeconds: focusedSeconds,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late FocusRepositoryImpl repository;

  setUp(() async {
    // No AppDatabase involved: the module creates its own table.
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    repository = FocusRepositoryImpl(
      dataSource: LocalFocusDataSource(databaseProvider: () async => db),
      useLocalDatabase: true,
    );
  });

  tearDown(() => db.close());

  test('ensureSchema is idempotent', () async {
    await LocalFocusDataSource.ensureSchema(db);
    await LocalFocusDataSource.ensureSchema(db);
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name = 'focus_sessions'",
    );
    expect(tables, hasLength(1));
  });

  test('saveSession then getSessions returns it, newest first', () async {
    await repository.saveSession(
      _session('a', startedAt: DateTime(2026, 10, 6, 8)),
    );
    await repository.saveSession(
      _session('b', startedAt: DateTime(2026, 10, 6, 11)),
    );

    final sessions = await repository.getSessions('u1');

    expect(sessions.map((s) => s.id), ['b', 'a']);
    expect(sessions.first.focusedSeconds, 1500);
    expect(sessions.first.completed, isTrue);
  });

  test('saving the same id twice keeps a single row', () async {
    await repository.saveSession(_session('a'));
    await repository.saveSession(_session('a', focusedSeconds: 600));

    final sessions = await repository.getSessions('u1');
    expect(sessions, hasLength(1));
    expect(sessions.single.focusedSeconds, 600);
  });

  test('sessions are scoped to the user', () async {
    await repository.saveSession(_session('a', userId: 'u1'));
    await repository.saveSession(_session('b', userId: 'u2'));

    expect((await repository.getSessions('u1')).single.id, 'a');
    expect((await repository.getSessions('u2')).single.id, 'b');
    expect(await repository.getSessions('nobody'), isEmpty);
  });

  test('since filters out older sessions', () async {
    await repository.saveSession(
      _session('old', startedAt: DateTime(2026, 9, 1)),
    );
    await repository.saveSession(
      _session('new', startedAt: DateTime(2026, 10, 5)),
    );

    final sessions = await repository.getSessions(
      'u1',
      since: DateTime(2026, 10, 1),
    );
    expect(sessions.map((s) => s.id), ['new']);
  });

  test('web-style in-memory mode works without SQLite', () async {
    final memory = FocusRepositoryImpl(useLocalDatabase: false);
    await memory.saveSession(_session('m'));
    // The remote source is unavailable in tests, so history comes from the
    // in-memory cache.
    final sessions = await memory.getSessions('u1');
    expect(sessions.map((s) => s.id), ['m']);
  });
}
