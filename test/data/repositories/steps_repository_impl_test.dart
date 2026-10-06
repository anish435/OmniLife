import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/datasources/local/steps_local_store.dart';
import 'package:omnilife/data/repositories/steps_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/location_sensor_fakes.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late FakeRemote remote;
  late DateTime now;
  String? uid;

  StepsRepositoryImpl build({Duration syncInterval = Duration.zero}) =>
      StepsRepositoryImpl(
        store: SqliteStepsStore(databaseProvider: () async => db),
        remote: remote,
        userIdProvider: () => uid,
        clock: () => now,
        syncInterval: syncInterval,
      );

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SqliteStepsStore.ensureSchema(db);
    remote = FakeRemote();
    now = DateTime(2026, 3, 10, 9);
    uid = 'u1';
  });

  tearDown(() => db.close());

  test('ensureSchema is idempotent', () async {
    await SqliteStepsStore.ensureSchema(db);
    await SqliteStepsStore.ensureSchema(db);
    expect(await build().todaySteps(), 0);
  });

  test('records deltas into today and the matching hour', () async {
    final repo = build();
    expect(await repo.recordCounter(1000, now), 0); // baseline
    now = DateTime(2026, 3, 10, 9, 20);
    expect(await repo.recordCounter(1150, now), 150);
    now = DateTime(2026, 3, 10, 10, 5);
    expect(await repo.recordCounter(1200, now), 50);

    expect(await repo.todaySteps(), 200);
    expect(await repo.hourlySteps(now), {9: 150, 10: 50});
  });

  test('reboot reset is credited correctly through the repository', () async {
    final repo = build();
    await repo.recordCounter(50000, now);
    now = DateTime(2026, 3, 10, 9, 30);
    await repo.recordCounter(50100, now);
    now = DateTime(2026, 3, 10, 9, 50);
    await repo.recordCounter(20, now); // rebooted

    expect(await repo.todaySteps(), 120);
  });

  test('baseline persists, so a new repository continues the count', () async {
    final first = build();
    await first.recordCounter(3000, now);
    now = DateTime(2026, 3, 10, 9, 40);
    await first.recordCounter(3100, now);

    final restarted = build(); // simulates an app restart
    now = DateTime(2026, 3, 10, 9, 50);
    await restarted.recordCounter(3160, now);

    expect(await restarted.todaySteps(), 160);
  });

  test('last7Days is oldest first and zero filled', () async {
    final repo = build();
    await repo.recordCounter(100, DateTime(2026, 3, 8, 8));
    await repo.recordCounter(400, DateTime(2026, 3, 8, 9)); // +300
    await repo.recordCounter(450, DateTime(2026, 3, 10, 8)); // gap: discarded
    await repo.recordCounter(500, DateTime(2026, 3, 10, 9)); // +50

    final week = await repo.last7Days();

    expect(week, hasLength(7));
    expect(week.first.key, '2026-03-04');
    expect(week.last.key, '2026-03-10');
    expect(week.map((d) => d.steps), [0, 0, 0, 0, 300, 0, 50]);
  });

  test('watchTodaySteps emits now and after each recorded change', () async {
    final repo = build();
    final seen = <int>[];
    final sub = repo.watchTodaySteps().listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen, [0]);

    await repo.recordCounter(10, now);
    now = DateTime(2026, 3, 10, 9, 5);
    await repo.recordCounter(45, now);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(seen.last, 35);
    await sub.cancel();
    await repo.dispose();
  });

  test('syncs dirty days to sensor_daily/{date} with merge', () async {
    final repo = build();
    await repo.recordCounter(100, now);
    now = DateTime(2026, 3, 10, 9, 10);
    await repo.recordCounter(160, now);
    await repo.syncPending();

    final doc = remote.doc('u1', 'sensor_daily', '2026-03-10')!;
    expect(doc['steps'], 60);
    expect(doc['date'], '2026-03-10');
    expect(doc['hourly'], {'09': 60});
  });

  test(
    'offline buffer: failed push stays dirty and retries idempotently',
    () async {
      final repo = build();
      remote.offline = true;
      await repo.recordCounter(100, now);
      now = DateTime(2026, 3, 10, 9, 10);
      await repo.recordCounter(180, now);
      expect(await repo.syncPending(), 0);
      expect(remote.doc('u1', 'sensor_daily', '2026-03-10'), isNull);

      remote.offline = false;
      expect(await repo.syncPending(), 1);
      expect(await repo.syncPending(), 0); // clean now
      final before = Map.of(remote.doc('u1', 'sensor_daily', '2026-03-10')!);

      // Re-pushing after more steps overwrites with the new total, not a sum.
      now = DateTime(2026, 3, 10, 9, 20);
      await repo.recordCounter(200, now);
      await repo.syncPending();
      final after = remote.doc('u1', 'sensor_daily', '2026-03-10')!;
      expect(before['steps'], 80);
      expect(after['steps'], 100);
    },
  );

  test('live sync is throttled by syncInterval', () async {
    final repo = build(syncInterval: const Duration(minutes: 5));
    await repo.recordCounter(0, now);
    now = DateTime(2026, 3, 10, 9, 1);
    await repo.recordCounter(10, now); // first sync attempt allowed
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final callsAfterFirst = remote.setCalls;
    expect(callsAfterFirst, 1);

    now = DateTime(2026, 3, 10, 9, 2);
    await repo.recordCounter(20, now); // inside the interval: no push
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.setCalls, callsAfterFirst);

    now = DateTime(2026, 3, 10, 9, 8);
    await repo.recordCounter(30, now); // interval elapsed
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.setCalls, callsAfterFirst + 1);
    expect(remote.doc('u1', 'sensor_daily', '2026-03-10')!['steps'], 30);
  });

  test('pullRemote fills history but never lowers local totals', () async {
    final repo = build();
    await repo.recordCounter(0, now);
    now = DateTime(2026, 3, 10, 9, 5);
    await repo.recordCounter(500, now);
    await remote.set('u1', 'sensor_daily', '2026-03-10', {
      'date': '2026-03-10',
      'steps': 300, // older/lower
    });
    await remote.set('u1', 'sensor_daily', '2026-03-09', {
      'date': '2026-03-09',
      'steps': 7000,
      'hourly': {'08': 4000, '17': 3000},
    });

    final updated = await repo.pullRemote();

    expect(updated, 1);
    expect(await repo.todaySteps(), 500);
    final week = await repo.last7Days();
    expect(week[5].steps, 7000);
    expect(await repo.hourlySteps(DateTime(2026, 3, 9)), {8: 4000, 17: 3000});
  });

  test('goal and tracking preferences persist per user', () async {
    final repo = build();
    expect(await repo.dailyGoal(), isNull);
    await repo.setDailyGoal(8000);
    await repo.setTrackingEnabled(true);
    expect(await repo.dailyGoal(), 8000);
    expect(await repo.isTrackingEnabled(), isTrue);

    uid = 'u2';
    expect(await repo.dailyGoal(), isNull);
    expect(await repo.isTrackingEnabled(), isFalse);

    uid = 'u1';
    await repo.setDailyGoal(null);
    expect(await repo.dailyGoal(), isNull);
  });

  test('without a signed-in user nothing is recorded', () async {
    uid = null;
    final repo = build();
    expect(await repo.recordCounter(100, now), 0);
    expect(await repo.todaySteps(), 0);
    expect(await repo.syncPending(), 0);
  });

  test(
    'in-memory store (web path) aggregates and syncs the same way',
    () async {
      final repo = StepsRepositoryImpl(
        store: InMemoryStepsStore(),
        remote: remote,
        userIdProvider: () => 'u1',
        clock: () => now,
        syncInterval: Duration.zero,
      );
      await repo.recordCounter(10, now);
      now = DateTime(2026, 3, 10, 9, 5);
      await repo.recordCounter(40, now);
      await repo.syncPending();
      expect(await repo.todaySteps(), 30);
      expect(remote.doc('u1', 'sensor_daily', '2026-03-10')!['steps'], 30);
    },
  );
}
