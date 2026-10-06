import 'package:omnilife/domain/entities/goal.dart';
import 'package:omnilife/domain/entities/habit.dart';
import 'package:omnilife/domain/repositories/goal_repository.dart';
import 'package:omnilife/domain/repositories/habit_repository.dart';

class FakeHabitRepository implements HabitRepository {
  final Map<String, Habit> habits = {};

  /// habitId -> completed dates
  final Map<String, Set<String>> logs = {};
  bool failToggle = false;
  bool failReads = false;
  int updateCalls = 0;

  @override
  Future<List<Habit>> getHabits(String userId) async {
    if (failReads) throw Exception('read failed');
    return habits.values.where((h) => h.userId == userId).toList();
  }

  @override
  Future<List<HabitLog>> getHabitLogs(String habitId) async => [
    for (final d in logs[habitId] ?? <String>{})
      HabitLog(id: '$habitId-$d', habitId: habitId, date: d),
  ];

  @override
  Future<Habit> createHabit(Habit habit) async {
    habits[habit.id] = habit;
    return habit;
  }

  @override
  Future<Habit> updateHabit(Habit habit) async {
    updateCalls++;
    habits[habit.id] = habit;
    return habit;
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    habits.remove(habitId);
    logs.remove(habitId);
  }

  @override
  Future<HabitLog?> toggleHabitLog(String habitId, String date) async {
    if (failToggle) throw Exception('toggle failed');
    final set = logs.putIfAbsent(habitId, () => {});
    if (set.remove(date)) return null;
    set.add(date);
    return HabitLog(id: '$habitId-$date', habitId: habitId, date: date);
  }
}

class FakeGoalRepository implements GoalRepository {
  final Map<String, Goal> goals = {};
  bool failWrites = false;

  @override
  Future<List<Goal>> getGoals(String userId) async =>
      goals.values.where((g) => g.userId == userId).toList();

  @override
  Future<Goal> createGoal(Goal goal) async {
    if (failWrites) throw Exception('write failed');
    goals[goal.id] = goal;
    return goal;
  }

  @override
  Future<Goal> updateGoal(Goal goal) async {
    if (failWrites) throw Exception('write failed');
    goals[goal.id] = goal;
    return goal;
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    if (failWrites) throw Exception('write failed');
    goals.remove(goalId);
  }
}
