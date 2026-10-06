import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../domain/usecases/habits/habit_streaks.dart';
import 'auth_controller.dart';
import 'goals_controller.dart';

class HabitsController extends GetxController {
  HabitsController({
    HabitRepository? habitRepository,
    AuthController? authController,
    DateTime Function()? clock,
  }) : _injectedRepository = habitRepository,
       _injectedAuth = authController,
       _clock = clock ?? DateTime.now;

  final HabitRepository? _injectedRepository;
  final AuthController? _injectedAuth;
  final DateTime Function() _clock;

  HabitRepository get _habitRepository =>
      _injectedRepository ?? Get.find<HabitRepository>();
  AuthController get _authController =>
      _injectedAuth ?? Get.find<AuthController>();

  final habits = <Habit>[].obs;
  // Map of habitId -> list of log dates ('YYYY-MM-DD')
  final habitLogs = <String, RxList<String>>{}.obs;

  final isLoading = false.obs;
  final errorMessage = Rx<String?>(null);

  String get _currentUserId => _authController.currentUser.value?.uid ?? '';

  /// Local calendar day, from the injected clock.
  DateTime get today => _clock();

  @override
  void onInit() {
    super.onInit();
    ever(_authController.currentUser, (_) => loadHabits());
    if (_authController.currentUser.value != null) {
      loadHabits();
    }
  }

  Future<void> loadHabits() async {
    if (_currentUserId.isEmpty) {
      habits.clear();
      habitLogs.clear();
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loaded = await _habitRepository.getHabits(_currentUserId);
      habits.assignAll(loaded);
      habitLogs.removeWhere((id, _) => !loaded.any((h) => h.id == id));

      // Load logs for each habit, then derive streaks from them.
      for (final habit in loaded) {
        final logs = await _habitRepository.getHabitLogs(habit.id);
        (habitLogs[habit.id] ??= <String>[].obs).assignAll(
          logs.where((e) => e.isCompleted).map((e) => e.date),
        );
        await _syncStreaks(habit.id);
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
      id: const Uuid().v4(),
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
    final previous = idx != -1 ? habits[idx] : null;
    if (idx != -1) {
      habits[idx] = updated;
    }

    try {
      await _habitRepository.updateHabit(updated);
      // Frequency may have changed, so streaks may too.
      await _syncStreaks(updated.id);
      return true;
    } catch (e) {
      if (previous != null) {
        final i = habits.indexWhere((x) => x.id == habit.id);
        if (i != -1) habits[i] = previous;
      }
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
      if (Get.isRegistered<GoalsController>()) {
        await Get.find<GoalsController>().unlinkHabit(id);
      }
      return true;
    } catch (e) {
      habits.insert(existingIdx, existing);
      if (logs != null) habitLogs[id] = logs;
      errorMessage.value = 'Failed to delete habit: $e';
      return false;
    }
  }

  /// Toggles the completion of [habitId] on [date] (local calendar day).
  ///
  /// Returns `true` if the day is now completed, `false` if it was cleared,
  /// and `null` if nothing changed (unknown habit, future date, or the save
  /// failed and the change was rolled back).
  Future<bool?> toggleHabitLog(String habitId, DateTime date) async {
    final dateStr = HabitStreaks.dateKey(date);
    if (HabitStreaks.dayNumberOfDate(date) >
        HabitStreaks.dayNumberOfDate(today)) {
      return null;
    }

    final logs = habitLogs[habitId];
    if (logs == null) return null;

    final wasCompleted = logs.contains(dateStr);

    // Optimistic
    if (wasCompleted) {
      logs.remove(dateStr);
    } else {
      logs.add(dateStr);
    }
    _recalculateInMemory(habitId);

    try {
      await _habitRepository.toggleHabitLog(habitId, dateStr);
      await _persistStreaks(habitId);
      return !wasCompleted;
    } catch (e) {
      // Revert
      if (wasCompleted) {
        logs.add(dateStr);
      } else {
        logs.remove(dateStr);
      }
      _recalculateInMemory(habitId);
      errorMessage.value = 'Failed to log habit: $e';
      return null;
    }
  }

  StreakResult streaksFor(Habit habit) => HabitStreaks.compute(
    completedDates: habitLogs[habit.id] ?? const <String>[],
    frequency: habit.frequency,
    specificDays: habit.specificDays,
    targetDaysPerWeek: habit.targetDaysPerWeek,
    today: today,
  );

  /// Updates the streak numbers on the in-memory habit so the UI reacts now.
  void _recalculateInMemory(String habitId) {
    final idx = habits.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;
    final habit = habits[idx];
    final r = streaksFor(habit);
    if (r.current != habit.currentStreak || r.longest != habit.longestStreak) {
      habits[idx] = habit.copyWith(
        currentStreak: r.current,
        longestStreak: r.longest,
      );
    }
  }

  /// Recomputes streaks and stores them if they differ from what is saved.
  Future<void> _syncStreaks(String habitId) async {
    final before = habits.firstWhereOrNull((h) => h.id == habitId);
    if (before == null) return;
    _recalculateInMemory(habitId);
    final after = habits.firstWhereOrNull((h) => h.id == habitId);
    if (after != null &&
        (after.currentStreak != before.currentStreak ||
            after.longestStreak != before.longestStreak)) {
      await _persistHabitQuietly(after);
    }
  }

  Future<void> _persistStreaks(String habitId) async {
    final habit = habits.firstWhereOrNull((h) => h.id == habitId);
    if (habit != null) await _persistHabitQuietly(habit);
  }

  Future<void> _persistHabitQuietly(Habit habit) async {
    try {
      await _habitRepository.updateHabit(habit);
    } catch (_) {
      // Streaks are derived data; they are recomputed on the next load.
    }
  }

  bool isHabitCompleted(String habitId, DateTime date) {
    final dateStr = HabitStreaks.dateKey(date);
    return habitLogs[habitId]?.contains(dateStr) ?? false;
  }

  /// Completed `yyyy-MM-dd` keys for [habitId] (reactive when read in Obx).
  Set<String> completedDatesFor(String habitId) =>
      (habitLogs[habitId] ?? const <String>[]).toSet();
}
