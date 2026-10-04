import 'package:sqflite/sqflite.dart';
import '../../models/wellness_log_model.dart';
import 'app_database.dart';

class LocalWellnessDataSource {
  Future<Database> get _db async => await AppDatabase.instance.database;

  Future<void> insertOrUpdateLog(WellnessLogModel log) async {
    final db = await _db;
    await db.insert(
      AppDatabase.wellnessTable,
      {
        'id': log.id,
        'user_id': log.id.split('_').first, // Simple way to extract userId if id is "userId_date"
        'date': log.date.toIso8601String().split('T').first,
        'water_intake_ml': log.waterIntakeMl,
        'sleep_duration_hours': log.sleepDurationHours,
        'sleep_quality': log.sleepQuality,
        'workout_duration_minutes': log.workoutDurationMinutes,
        'workout_type': log.workoutType,
        'mood_score': log.moodScore,
        'synced': log.synced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WellnessLogModel?> getLogForDate(String userId, DateTime date) async {
    final db = await _db;
    final dateStr = date.toIso8601String().split('T').first;
    final maps = await db.query(
      AppDatabase.wellnessTable,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, dateStr],
    );

    if (maps.isEmpty) return null;

    return _fromDbMap(maps.first);
  }

  Future<List<WellnessLogModel>> getLogsForMonth(String userId, int year, int month) async {
    final db = await _db;
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = '$year-$monthStr';

    final maps = await db.query(
      AppDatabase.wellnessTable,
      where: 'user_id = ? AND date LIKE ?',
      whereArgs: [userId, '$prefix%'],
      orderBy: 'date ASC',
    );

    return maps.map(_fromDbMap).toList();
  }

  Future<List<WellnessLogModel>> getUnsyncedLogs(String userId) async {
    final db = await _db;
    final maps = await db.query(
      AppDatabase.wellnessTable,
      where: 'user_id = ? AND synced = 0',
      whereArgs: [userId],
    );

    return maps.map(_fromDbMap).toList();
  }

  Future<void> markAsSynced(String id) async {
    final db = await _db;
    await db.update(
      AppDatabase.wellnessTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  WellnessLogModel _fromDbMap(Map<String, dynamic> map) {
    return WellnessLogModel(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      waterIntakeMl: map['water_intake_ml'] as int,
      sleepDurationHours: (map['sleep_duration_hours'] as num).toDouble(),
      sleepQuality: map['sleep_quality'] as int,
      workoutDurationMinutes: map['workout_duration_minutes'] as int,
      workoutType: map['workout_type'] as String,
      moodScore: map['mood_score'] as int,
      synced: (map['synced'] as int) == 1,
    );
  }
}
