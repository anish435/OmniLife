import 'package:sqflite/sqflite.dart';

import '../../models/calendar_event_model.dart';
import 'app_database.dart';

/// Raw SQLite access for the `calendar_events` table.
class LocalCalendarDataSource {
  LocalCalendarDataSource({Future<Database> Function()? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;

  Future<void> insertEvent(CalendarEventModel event) async {
    final db = await _databaseProvider();
    await db.insert(
      AppDatabase.eventsTable,
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CalendarEventModel>> getEventsForRange(
    String userId,
    int startMillis,
    int endMillis,
  ) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.eventsTable,
      where: 'user_id = ? AND start_at < ? AND end_at > ?',
      whereArgs: [userId, endMillis, startMillis],
      orderBy: 'start_at ASC',
    );
    return rows.map(CalendarEventModel.fromMap).toList();
  }

  Future<List<CalendarEventModel>> getAllEvents(String userId) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.eventsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_at ASC',
    );
    return rows.map(CalendarEventModel.fromMap).toList();
  }

  Future<CalendarEventModel?> getEventById(String id) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      AppDatabase.eventsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CalendarEventModel.fromMap(rows.first);
  }

  Future<bool> updateEvent(CalendarEventModel event) async {
    final db = await _databaseProvider();
    final count = await db.update(
      AppDatabase.eventsTable,
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    return count > 0;
  }

  Future<bool> deleteEvent(String id) async {
    final db = await _databaseProvider();
    final count = await db.delete(
      AppDatabase.eventsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }
}
