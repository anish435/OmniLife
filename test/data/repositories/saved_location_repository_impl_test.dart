import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/datasources/local/saved_location_local_store.dart';
import 'package:omnilife/data/repositories/saved_location_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/location_sensor_fakes.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late FakeRemote remote;
  late SavedLocationRepositoryImpl repo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SqliteSavedLocationStore.ensureSchema(db);
    remote = FakeRemote();
    repo = SavedLocationRepositoryImpl(
      localStore: SqliteSavedLocationStore(databaseProvider: () async => db),
      remote: remote,
    );
  });

  tearDown(() => db.close());

  test('ensureSchema is idempotent', () async {
    await SqliteSavedLocationStore.ensureSchema(db);
    await SqliteSavedLocationStore.ensureSchema(db);
    expect(await repo.getLocations('u1'), isEmpty);
  });

  test('save persists locally and round-trips every field', () async {
    final p = place('a', radius: 250, taskId: 't9', eventId: 'e3');
    await repo.save(p);

    final loaded = await repo.getLocations('u1');
    expect(loaded, [p]);
  });

  test('save pushes to users/{uid}/locations/{id} and marks synced', () async {
    await repo.save(place('a'));
    await repo.flush();

    final doc = remote.doc('u1', 'locations', 'a')!;
    expect(doc['name'], 'Place a');
    expect(doc['radiusMeters'], 100);
    // Nothing left pending.
    expect(await repo.syncPending('u1'), 0);
    expect(remote.setCalls, 1);
  });

  test('offline save is kept and pushed later by syncPending', () async {
    remote.offline = true;
    await repo.save(place('a'));
    await repo.flush();

    expect(await repo.getLocations('u1'), hasLength(1)); // not lost
    expect(remote.doc('u1', 'locations', 'a'), isNull);

    remote.offline = false;
    expect(await repo.syncPending('u1'), 1);
    expect(remote.doc('u1', 'locations', 'a'), isNotNull);
    expect(await repo.syncPending('u1'), 0); // idempotent afterwards
  });

  test('update replaces the row and the remote document', () async {
    await repo.save(place('a'));
    await repo.save(place('a').copyWith(name: 'Office', radiusMeters: 300));
    await repo.flush();

    final all = await repo.getLocations('u1');
    expect(all, hasLength(1));
    expect(all.single.name, 'Office');
    expect(remote.doc('u1', 'locations', 'a')!['radiusMeters'], 300);
  });

  test('delete hides the row immediately and removes the remote doc', () async {
    await repo.save(place('a'));
    await repo.flush();
    await repo.delete('u1', 'a');

    expect(await repo.getLocations('u1'), isEmpty);
    await repo.flush();
    expect(remote.doc('u1', 'locations', 'a'), isNull);
  });

  test('offline delete is retried and never resurrected by refresh', () async {
    await repo.save(place('a'));
    await repo.flush();

    remote.offline = true;
    await repo.delete('u1', 'a');
    await repo.flush();
    remote.offline = false;

    // Remote still has it, but the pending delete must win.
    final merged = await repo.refreshFromRemote('u1');
    expect(merged, isEmpty);

    expect(await repo.syncPending('u1'), 1);
    expect(remote.doc('u1', 'locations', 'a'), isNull);
  });

  test('rows are scoped per user', () async {
    await repo.save(place('a', userId: 'u1'));
    await repo.save(place('b', userId: 'u2'));

    expect((await repo.getLocations('u1')).map((l) => l.id), ['a']);
    expect((await repo.getLocations('u2')).map((l) => l.id), ['b']);
  });

  test('refreshFromRemote imports missing remote places', () async {
    await remote.set('u1', 'locations', 'r1', {
      'id': 'r1',
      'name': 'From cloud',
      'latitude': 1.5,
      'longitude': 2.5,
      'radiusMeters': 80,
      'linkedTaskId': 't1',
      'createdAt': 1000,
      'updatedAt': 2000,
    });

    final merged = await repo.refreshFromRemote('u1');

    expect(merged.single.name, 'From cloud');
    expect(merged.single.linkedTaskId, 't1');
    // And it is now local too (survives going offline).
    remote.offline = true;
    expect(await repo.getLocations('u1'), hasLength(1));
  });

  test('refreshFromRemote keeps a newer pending local edit', () async {
    remote.offline = true;
    await repo.save(place('a').copyWith(name: 'Local edit'));
    await repo.flush();
    remote.offline = false;
    await remote.set('u1', 'locations', 'a', {
      'id': 'a',
      'name': 'Stale cloud',
      'latitude': 12.9716,
      'longitude': 77.5946,
      'radiusMeters': 100,
      'createdAt': 0,
      'updatedAt': 999999999999,
    });

    final merged = await repo.refreshFromRemote('u1');
    expect(merged.single.name, 'Local edit');
  });

  test('in-memory store (web path) behaves the same', () async {
    final web = SavedLocationRepositoryImpl(
      localStore: InMemorySavedLocationStore(),
      remote: remote,
    );
    await web.save(place('w'));
    await web.flush();
    expect(await web.getLocations('u1'), hasLength(1));
    await web.delete('u1', 'w');
    await web.flush();
    expect(await web.getLocations('u1'), isEmpty);
    expect(remote.doc('u1', 'locations', 'w'), isNull);
  });
}
