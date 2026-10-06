import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/entities/habit.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/goals_controller.dart';
import 'package:omnilife/presentation/controllers/habits_controller.dart';

import '../../support/fake_habit_repositories.dart';
import 'task_controller_test.dart' show FakeAuthRepository;

void main() {
  const user = AppUser(uid: 'u1', email: 'a@b.c');
  late FakeHabitRepository repo;
  late AuthController auth;
  late HabitsController controller;
  // Wednesday 11 March 2026, 09:00.
  var now = DateTime(2026, 3, 11, 9);

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    now = DateTime(2026, 3, 11, 9);
    auth = AuthController(authRepository: FakeAuthRepository(user));
    auth.onInit();
    await Future<void>.delayed(Duration.zero);
    repo = FakeHabitRepository();
    controller = HabitsController(
      habitRepository: repo,
      authController: auth,
      clock: () => now,
    );
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(Get.reset);

  Future<Habit> create({
    HabitFrequency frequency = HabitFrequency.daily,
    List<int> days = const [],
    int target = 7,
  }) async => (await controller.createHabit(
    title: 'Read',
    frequency: frequency,
    specificDays: days,
    targetDaysPerWeek: target,
  ))!;

  test('createHabit stores frequency settings', () async {
    final h = await create(
      frequency: HabitFrequency.specificDays,
      days: [1, 3, 5],
      target: 3,
    );
    expect(repo.habits[h.id]!.specificDays, [1, 3, 5]);
    expect(repo.habits[h.id]!.frequency, HabitFrequency.specificDays);
    expect(controller.habitLogs[h.id], isEmpty);
  });

  test('toggle completes today, updates streak and persists', () async {
    final h = await create();
    final result = await controller.toggleHabitLog(h.id, now);
    expect(result, isTrue);
    expect(controller.isHabitCompleted(h.id, now), isTrue);
    expect(repo.logs[h.id], {'2026-03-11'});
    final stored = repo.habits[h.id]!;
    expect((stored.currentStreak, stored.longestStreak), (1, 1));
    expect(controller.habits.single.currentStreak, 1);
  });

  test('toggling again undoes the completion and the streak', () async {
    final h = await create();
    await controller.toggleHabitLog(h.id, now);
    final result = await controller.toggleHabitLog(h.id, now);
    expect(result, isFalse);
    expect(repo.logs[h.id], isEmpty);
    expect(repo.habits[h.id]!.currentStreak, 0);
    expect(repo.habits[h.id]!.longestStreak, 0);
  });

  test('yesterday-only streak is alive while today is still open', () async {
    final h = await create();
    await controller.toggleHabitLog(h.id, DateTime(2026, 3, 10));
    await controller.toggleHabitLog(h.id, DateTime(2026, 3, 9));
    expect(controller.habits.single.currentStreak, 2);
    // The next morning, nothing logged for the 11th yet: still 2.
    now = DateTime(2026, 3, 11, 8);
    expect(controller.streaksFor(controller.habits.single).current, 2);
    // Two days after the last log, it is broken but longest stays.
    now = DateTime(2026, 3, 13, 8);
    final r = controller.streaksFor(controller.habits.single);
    expect((r.current, r.longest), (0, 2));
  });

  test('future days cannot be logged', () async {
    final h = await create();
    final result = await controller.toggleHabitLog(h.id, DateTime(2026, 3, 12));
    expect(result, isNull);
    expect(repo.logs[h.id] ?? <String>{}, isEmpty);
  });

  test('failed save rolls back the log and the streak', () async {
    final h = await create();
    repo.failToggle = true;
    final result = await controller.toggleHabitLog(h.id, now);
    expect(result, isNull);
    expect(controller.isHabitCompleted(h.id, now), isFalse);
    expect(controller.habits.single.currentStreak, 0);
    expect(controller.errorMessage.value, contains('Failed to log habit'));
  });

  test(
    'loadHabits derives streaks from stored logs, not stored numbers',
    () async {
      final h = Habit(
        id: 'h1',
        userId: 'u1',
        title: 'Run',
        currentStreak: 40, // stale
        longestStreak: 99, // stale
        createdAt: now,
        updatedAt: now,
      );
      repo.habits['h1'] = h;
      repo.logs['h1'] = {'2026-03-11', '2026-03-10', '2026-03-05'};
      await controller.loadHabits();
      final loaded = controller.habits.single;
      expect((loaded.currentStreak, loaded.longestStreak), (2, 2));
      expect(
        repo.habits['h1']!.currentStreak,
        2,
        reason: 'corrected value saved',
      );
    },
  );

  test('changing frequency recomputes the streak', () async {
    final h = await create();
    // Mon 9 and Wed 11 done, Tue 10 missed.
    await controller.toggleHabitLog(h.id, DateTime(2026, 3, 9));
    await controller.toggleHabitLog(h.id, DateTime(2026, 3, 11));
    expect(controller.habits.single.currentStreak, 1);
    await controller.updateHabit(
      controller.habits.single.copyWith(
        frequency: HabitFrequency.specificDays,
        specificDays: const [1, 3],
      ),
    );
    expect(controller.habits.single.currentStreak, 2);
  });

  test('load failure surfaces an error and clears loading', () async {
    repo.failReads = true;
    await controller.loadHabits();
    expect(controller.errorMessage.value, contains('Failed to load habits'));
    expect(controller.isLoading.value, isFalse);
  });

  test('deleting a habit removes logs and unlinks its goals', () async {
    final goalRepo = FakeGoalRepository();
    final goals = GoalsController(
      goalRepository: goalRepo,
      authController: auth,
    );
    Get.put<GoalsController>(goals);
    goals.onInit();
    await Future<void>.delayed(Duration.zero);

    final h = await create();
    await controller.toggleHabitLog(h.id, now);
    final goal = await goals.createGoal(title: 'Finish', linkedHabitId: h.id);
    expect(goals.goalsForHabit(h.id).length, 1);

    expect(await controller.deleteHabit(h.id), isTrue);
    expect(repo.habits, isEmpty);
    expect(repo.logs[h.id], isNull);
    expect(controller.habitLogs.containsKey(h.id), isFalse);
    expect(goals.goals.single.id, goal!.id);
    expect(goals.goals.single.linkedHabitId, isNull);
    expect(goalRepo.goals[goal.id]!.linkedHabitId, isNull);
  });
}
