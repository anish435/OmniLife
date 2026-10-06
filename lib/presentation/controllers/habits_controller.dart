import 'package:get/get.dart';
import '../../core/services/analytics_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import 'auth_controller.dart';

class HabitsController extends GetxController {
  final _habitRepository = Get.find<HabitRepository>();
  final _authController = Get.find<AuthController>();

  final habits = <Habit>[].obs;
  // Map of habitId -> list of log dates ('YYYY-MM-DD')
  final habitLogs = <String, RxList<String>>{}.obs;

  final isLoading = false.obs;
  final errorMessage = Rx<String?>(null);

  String get _currentUserId => _authController.currentUser.value?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    ever(_authController.currentUser, (_) => loadHabits());
    if (_authController.currentUser.value != null) {
      loadHabits();
    }
  }

  Future<void> loadHabits() async {
    if (_currentUserId.isEmpty) return;
    
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loaded = await _habitRepository.getHabits(_currentUserId);
      habits.assignAll(loaded);

      // Load logs for each habit
      for (final habit in habits) {
        if (!habitLogs.containsKey(habit.id)) {
          habitLogs[habit.id] = <String>[].obs;
        }
        final logs = await _habitRepository.getHabitLogs(habit.id);
        habitLogs[habit.id]!.assignAll(logs.map((e) => e.date));
        
        // Recalculate streak
        _recalculateStreak(habit);
      }
    } catch (e) {
      errorMessage.value = 'Failed to load habits: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<Habit?> createHabit({
    required String title,
    String description = '',
    HabitFrequency frequency = HabitFrequency.daily,
    int targetDaysPerWeek = 7,
    List<int> specificDays = const [],
    String colorTag = 'default',
  }) async {
    if (_currentUserId.isEmpty) return null;

    final now = DateTime.now();
    final newHabit = Habit(
      id: Uuid().v4(),
      userId: _currentUserId,
      title: title,
      description: description,
      frequency: frequency,
      targetDaysPerWeek: targetDaysPerWeek,
      specificDays: specificDays,
      colorTag: colorTag,
      createdAt: now,
      updatedAt: now,
    );

    habits.add(newHabit);
    habitLogs[newHabit.id] = <String>[].obs;

    try {
      final created = await _habitRepository.createHabit(newHabit);
      final idx = habits.indexWhere((e) => e.id == newHabit.id);
      if (idx != -1) {
        habits[idx] = created;
      }
      return created;
    } catch (e) {
      habits.removeWhere((e) => e.id == newHabit.id);
      habitLogs.remove(newHabit.id);
      errorMessage.value = 'Failed to create habit: $e';
      return null;
    }
  }

  Future<bool> updateHabit(Habit habit) async {
    if (_currentUserId.isEmpty) return false;

    final updated = habit.copyWith(updatedAt: DateTime.now());
    
    final idx = habits.indexWhere((e) => e.id == habit.id);
    if (idx != -1) {
      habits[idx] = updated;
    }

    try {
      await _habitRepository.updateHabit(updated);
      return true;
    } catch (e) {
      errorMessage.value = 'Failed to update habit: $e';
      return false;
    }
  }

  Future<bool> deleteHabit(String id) async {
    final existingIdx = habits.indexWhere((e) => e.id == id);
    if (existingIdx == -1) return false;
    
    final existing = habits[existingIdx];
    habits.removeAt(existingIdx);
    
    final logs = habitLogs.remove(id);

    try {
      await _habitRepository.deleteHabit(id);
      return true;
    } catch (e) {
      habits.insert(existingIdx, existing);
      if (logs != null) habitLogs[id] = logs;
      errorMessage.value = 'Failed to delete habit: $e';
      return false;
    }
  }

  Future<void> toggleHabitLog(String habitId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    final logs = habitLogs[habitId];
    if (logs == null) return;
    
    final wasCompleted = logs.contains(dateStr);
    
    // Optimistic
    if (wasCompleted) {
      logs.remove(dateStr);
    } else {
      logs.add(dateStr);
    }

    final habitIdx = habits.indexWhere((e) => e.id == habitId);
    if (habitIdx != -1) {
      _recalculateStreak(habits[habitIdx]);
    }

    try {
      await _habitRepository.toggleHabitLog(habitId, dateStr);
      if (!wasCompleted) {
        AnalyticsService.instance.logEvent(AnalyticsEvents.habitCompleted);
      }
    } catch (e) {
      // Revert
      if (wasCompleted) {
        logs.add(dateStr);
      } else {
        logs.remove(dateStr);
      }
      if (habitIdx != -1) {
        _recalculateStreak(habits[habitIdx]);
      }
      errorMessage.value = 'Failed to log habit: $e';
    }
  }
  
  void _recalculateStreak(Habit habit) {
    final logs = habitLogs[habit.id]?.toList() ?? [];
    if (logs.isEmpty) {
      if (habit.currentStreak != 0 || habit.longestStreak != 0) {
        updateHabit(habit.copyWith(currentStreak: 0));
      }
      return;
    }
    
    logs.sort((a, b) => b.compareTo(a)); // Descending
    
    int current = 0;
    int max = habit.longestStreak;
    
    DateTime date = DateTime.now();
    
    // Naive daily streak calculation
    // If not logged today, check yesterday. If yesterday is logged, streak continues.
    // Otherwise streak is 0.
    final todayStr = DateFormat('yyyy-MM-dd').format(date);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(date.subtract(const Duration(days: 1)));
    
    if (logs.contains(todayStr)) {
      current = 1;
      date = date.subtract(const Duration(days: 1));
      while (logs.contains(DateFormat('yyyy-MM-dd').format(date))) {
        current++;
        date = date.subtract(const Duration(days: 1));
      }
    } else if (logs.contains(yesterdayStr)) {
      current = 1;
      date = date.subtract(const Duration(days: 2));
      while (logs.contains(DateFormat('yyyy-MM-dd').format(date))) {
        current++;
        date = date.subtract(const Duration(days: 1));
      }
    } else {
      current = 0;
    }
    
    if (current > max) max = current;
    
    if (current != habit.currentStreak || max != habit.longestStreak) {
      updateHabit(habit.copyWith(currentStreak: current, longestStreak: max));
    }
  }
  
  bool isHabitCompleted(String habitId, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return habitLogs[habitId]?.contains(dateStr) ?? false;
  }
}
