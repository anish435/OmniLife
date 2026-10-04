import '../entities/habit.dart';

abstract class HabitRepository {
  /// Fetches all habits for a user
  Future<List<Habit>> getHabits(String userId);

  /// Fetches logs for a given habit (optionally within a date range)
  Future<List<HabitLog>> getHabitLogs(String habitId);

  /// Creates a new habit
  Future<Habit> createHabit(Habit habit);

  /// Updates an existing habit
  Future<Habit> updateHabit(Habit habit);

  /// Permanently deletes a habit and its logs
  Future<void> deleteHabit(String habitId);

  /// Toggles a habit log for a specific date (creates if not exists, deletes or marks false if exists)
  Future<HabitLog?> toggleHabitLog(String habitId, String date);
}
