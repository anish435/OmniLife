import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/datasources/local/app_database.dart';
import 'package:omnilife/data/datasources/local/local_calendar_data_source.dart';
import 'package:omnilife/data/repositories/calendar_repository_impl.dart';
import 'package:omnilife/domain/entities/calendar_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CalendarEvent _newEvent(
  String id, {
  String userId = 'u1',
  required DateTime start,
  required DateTime end,
}) {
  return CalendarEvent(
    id: id,
    userId: userId,
    title: 'Event $id',
    startAt: start,
    endAt: end,
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late CalendarRepositoryImpl repository;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    );
    repository = CalendarRepositoryImpl(
      dataSource: LocalCalendarDataSource(databaseProvider: () async => db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('createEvent then getEventsForRange returns events in range', () async {
    final start = DateTime(2026, 10, 3, 10, 0);
    final end = DateTime(2026, 10, 3, 11, 0);

    await repository.createEvent(_newEvent('e1', start: start, end: end));

    final rangeEvents = await repository.getEventsForRange(
      'u1',
      DateTime(2026, 10, 3, 0, 0),
      DateTime(2026, 10, 3, 23, 59),
    );

    expect(rangeEvents, hasLength(1));
    expect(rangeEvents.first.id, 'e1');
  });

  test('getEventsForRange filters out events outside the range', () async {
    // Event on Oct 3
    await repository.createEvent(_newEvent(
      'e1',
      start: DateTime(2026, 10, 3, 10),
      end: DateTime(2026, 10, 3, 11),
    ));

    // Event on Oct 10
    await repository.createEvent(_newEvent(
      'e2',
      start: DateTime(2026, 10, 10, 10),
      end: DateTime(2026, 10, 10, 11),
    ));

    final oct3Events = await repository.getEventsForRange(
      'u1',
      DateTime(2026, 10, 3, 0),
      DateTime(2026, 10, 4, 0),
    );

    expect(oct3Events, hasLength(1));
    expect(oct3Events.first.id, 'e1');
  });

  test('getEventsForRange only returns events for the given user', () async {
    await repository.createEvent(_newEvent(
      'e1',
      userId: 'u1',
      start: DateTime(2026, 10, 3, 10),
      end: DateTime(2026, 10, 3, 11),
    ));
    await repository.createEvent(_newEvent(
      'e2',
      userId: 'other_user',
      start: DateTime(2026, 10, 3, 10),
      end: DateTime(2026, 10, 3, 11),
    ));

    final user1Events = await repository.getEventsForRange(
      'u1',
      DateTime(2026, 10, 3, 0),
      DateTime(2026, 10, 4, 0),
    );

    expect(user1Events, hasLength(1));
    expect(user1Events.first.userId, 'u1');
  });

  test('updateEvent modifies title and timestamps', () async {
    final original = await repository.createEvent(_newEvent(
      'e1',
      start: DateTime(2026, 10, 3, 10),
      end: DateTime(2026, 10, 3, 11),
    ));

    final updated = await repository.updateEvent(
      original.copyWith(title: 'Renamed Meeting'),
    );

    expect(updated.title, 'Renamed Meeting');
    final fetched = await repository.getEvent('e1');
    expect(fetched?.title, 'Renamed Meeting');
  });

  test('deleteEvent removes event from database and memory cache', () async {
    await repository.createEvent(_newEvent(
      'e1',
      start: DateTime(2026, 10, 3, 10),
      end: DateTime(2026, 10, 3, 11),
    ));

    await repository.deleteEvent('e1');

    final fetched = await repository.getEvent('e1');
    expect(fetched, isNull);
  });
}
