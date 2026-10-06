import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/entities/goal.dart';
import 'package:omnilife/domain/entities/habit.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/goal_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/goals_controller.dart';
import 'package:omnilife/presentation/controllers/habits_controller.dart';
import 'package:omnilife/presentation/pages/habits/habit_detail_page.dart';
import 'package:omnilife/presentation/pages/habits/habits_page.dart';

import '../../support/fake_habit_repositories.dart';
import '../controllers/task_controller_test.dart' show FakeAuthRepository;

void main() {
  const user = AppUser(uid: 'u1', email: 'a@b.c');
  late FakeHabitRepository habitRepo;
  late FakeGoalRepository goalRepo;
  late AuthController auth;
  late HabitsController habits;
  late GoalsController goals;
  final now = DateTime(2026, 3, 11, 9); // Wednesday

  Habit habit(String id, String title, {List<int> days = const []}) => Habit(
    id: id,
    userId: 'u1',
    title: title,
    frequency: days.isEmpty
        ? HabitFrequency.daily
        : HabitFrequency.specificDays,
    specificDays: days,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    auth = AuthController(authRepository: FakeAuthRepository(user));
    auth.onInit();
    await Future<void>.delayed(Duration.zero);
    habitRepo = FakeHabitRepository();
    goalRepo = FakeGoalRepository();
    habits = HabitsController(
      habitRepository: habitRepo,
      authController: auth,
      clock: () => now,
    );
    goals = GoalsController(goalRepository: goalRepo, authController: auth);
    Get.put<HabitsController>(habits);
    Get.put<GoalRepository>(goalRepo);
    Get.put<GoalsController>(goals);
  });

  tearDown(Get.reset);

  Future<void> pumpPage(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: home));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('empty state offers creating a habit and a goal', (tester) async {
    await pumpPage(tester, const HabitsPage());
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('No goals yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state with retry when habits fail to load', (
    tester,
  ) async {
    habitRepo.failReads = true;
    await pumpPage(tester, const HabitsPage());
    await habits.loadHabits();
    await tester.pump();
    expect(find.textContaining('Failed to load habits'), findsOneWidget);
    habitRepo.failReads = false;
    habitRepo.habits['h1'] = habit('h1', 'Read');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('tapping a day completes it: persisted, streak and UI updated', (
    tester,
  ) async {
    habitRepo.habits['h1'] = habit('h1', 'Read');
    await pumpPage(tester, const HabitsPage());
    await habits.loadHabits();
    await tester.pump();
    expect(find.text('0 day streak'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-h1-2026-03-11')));
    await tester.pumpAndSettle();
    expect(habitRepo.logs['h1'], {'2026-03-11'});
    expect(find.text('1 day streak'), findsOneWidget);

    // The strip covers 7 days ending today; yesterday extends the streak.
    await tester.tap(find.byKey(const ValueKey('day-h1-2026-03-10')));
    await tester.pumpAndSettle();
    expect(find.text('2 day streak'), findsOneWidget);
    expect(habitRepo.habits['h1']!.longestStreak, 2);

    // Tapping again clears it.
    await tester.tap(find.byKey(const ValueKey('day-h1-2026-03-11')));
    await tester.pumpAndSettle();
    expect(habitRepo.logs['h1'], {'2026-03-10'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save shows an error confirmation and rolls back', (
    tester,
  ) async {
    habitRepo.habits['h1'] = habit('h1', 'Read');
    await pumpPage(tester, const HabitsPage());
    await habits.loadHabits();
    await tester.pump();
    habitRepo.failToggle = true;
    await tester.tap(find.byKey(const ValueKey('day-h1-2026-03-11')));
    await tester.pumpAndSettle();
    expect(find.text('Could not update habit'), findsOneWidget);
    expect(find.text('0 day streak'), findsOneWidget);
  });

  testWidgets('goals show milestone progress and ticking persists', (
    tester,
  ) async {
    habitRepo.habits['h1'] = habit('h1', 'Run');
    final created = DateTime(2026, 2, 1);
    goalRepo.goals['g1'] = Goal(
      id: 'g1',
      userId: 'u1',
      title: 'Run a 10k',
      linkedHabitId: 'h1',
      targetDate: DateTime(2026, 9, 1),
      milestones: const [
        GoalMilestone(id: 'a', title: 'Run 5k'),
        GoalMilestone(id: 'b', title: 'Run 8k'),
        GoalMilestone(id: 'c', title: 'Run 10k'),
      ],
      createdAt: created,
      updatedAt: created,
    );
    await pumpPage(tester, const HabitsPage());
    await habits.loadHabits();
    await goals.loadGoals();
    await tester.pump();

    // Shown on the goal tile and on the linked habit card.
    expect(find.text('0 of 3 milestones'), findsNWidgets(2));
    expect(find.text('Goal: Run a 10k'), findsOneWidget);
    expect(find.textContaining('Habit: Run'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('milestone-a')));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 milestones'), findsNWidgets(2));
    expect(goalRepo.goals['g1']!.milestones.first.done, isTrue);
  });

  testWidgets('create a goal linked to a habit with milestones', (
    tester,
  ) async {
    habitRepo.habits['h1'] = habit('h1', 'Run');
    await pumpPage(tester, const HabitsPage());
    await habits.loadHabits();
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('new-goal')));
    await tester.tap(find.byKey(const ValueKey('new-goal')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('goal-title')),
      'Run a 10k',
    );
    await tester.enterText(
      find.byKey(const ValueKey('goal-target')),
      'Under an hour',
    );

    await tester.tap(find.byKey(const ValueKey('goal-habit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-milestone')));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Milestone'),
      'Run 5k',
    );

    await tester.tap(find.byKey(const ValueKey('save-goal')));
    await tester.pumpAndSettle();

    final saved = goalRepo.goals.values.single;
    expect(saved.title, 'Run a 10k');
    expect(saved.targetDescription, 'Under an hour');
    expect(saved.linkedHabitId, 'h1');
    expect(saved.milestones.map((m) => m.title), ['Run 5k']);
    expect(find.text('Goal created'), findsWidgets);
    expect(find.text('Run a 10k'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal title is required', (tester) async {
    await pumpPage(tester, const HabitsPage());
    await tester.ensureVisible(find.byKey(const ValueKey('new-goal')));
    await tester.tap(find.byKey(const ValueKey('new-goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-goal')));
    await tester.pumpAndSettle();
    expect(find.text('Give the goal a title'), findsOneWidget);
    expect(goalRepo.goals, isEmpty);
  });

  testWidgets('detail page shows heatmap driven by logs and today toggle', (
    tester,
  ) async {
    habitRepo.habits['h1'] = habit('h1', 'Read');
    habitRepo.logs['h1'] = {'2026-03-10', '2026-03-09', '2026-01-15'};
    await pumpPage(tester, const HabitsPage());
    await habits.loadHabits();
    await tester.pump();

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    expect(find.text('3 of 365 days, longest streak 2 days'), findsOneWidget);
    expect(find.text('Not done today'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-today-2026-03-11')));
    await tester.pumpAndSettle();
    expect(find.text('Done today'), findsOneWidget);
    expect(find.text('4 of 365 days, longest streak 3 days'), findsOneWidget);
    expect(habitRepo.logs['h1'], contains('2026-03-11'));

    await tester.tap(find.byKey(const ValueKey('heat-2026-03-11')));
    await tester.pump();
    expect(find.text('Wednesday 11 March 2026: Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail page lists linked goals and can add one', (tester) async {
    habitRepo.habits['h1'] = habit('h1', 'Read');
    goalRepo.goals['g1'] = Goal(
      id: 'g1',
      userId: 'u1',
      title: 'Finish 12 books',
      linkedHabitId: 'h1',
      milestones: const [
        GoalMilestone(id: 'a', title: '4 books', done: true),
        GoalMilestone(id: 'b', title: '8 books'),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await habits.loadHabits();
    await goals.loadGoals();
    await pumpPage(tester, const HabitDetailPage(habitId: 'h1'));

    expect(find.text('Finish 12 books'), findsOneWidget);
    expect(find.text('1 of 2 milestones'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('add-goal-for-habit')),
    );
    await tester.tap(find.byKey(const ValueKey('add-goal-for-habit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-title')),
      'Read daily',
    );
    await tester.tap(find.byKey(const ValueKey('save-goal')));
    await tester.pumpAndSettle();
    final added = goalRepo.goals.values.firstWhere(
      (g) => g.title == 'Read daily',
    );
    expect(added.linkedHabitId, 'h1', reason: 'preselected from the habit');
  });

  testWidgets('detail page for a missing habit shows an empty state', (
    tester,
  ) async {
    await pumpPage(tester, const HabitDetailPage(habitId: 'nope'));
    expect(find.text('This habit no longer exists'), findsOneWidget);
  });

  testWidgets('creating a habit with specific days saves the schedule', (
    tester,
  ) async {
    await pumpPage(tester, const HabitsPage());
    await tester.tap(find.byTooltip('New habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('habit-title')), 'Gym');
    await tester.tap(find.text('Specific days'));
    await tester.pump();

    // Saving with no day selected is rejected.
    await tester.tap(find.byTooltip('Save habit'));
    await tester.pump();
    expect(find.text('Pick at least one day'), findsOneWidget);
    expect(habitRepo.habits, isEmpty);

    await tester.tap(find.byKey(const ValueKey('day-chip-1')));
    await tester.tap(find.byKey(const ValueKey('day-chip-3')));
    await tester.tap(find.byKey(const ValueKey('day-chip-5')));
    await tester.pump();
    await tester.tap(find.byTooltip('Save habit'));
    await tester.pumpAndSettle();

    final saved = habitRepo.habits.values.single;
    expect(saved.frequency, HabitFrequency.specificDays);
    expect(saved.specificDays, [1, 3, 5]);
    expect(saved.targetDaysPerWeek, 3);
    expect(find.text('Habit created'), findsWidgets);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('0 in a row'), findsOneWidget);
  });

  testWidgets('weekly target habit saves target and uses week wording', (
    tester,
  ) async {
    await pumpPage(tester, const HabitsPage());
    await tester.tap(find.byTooltip('New habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('habit-title')), 'Swim');
    await tester.tap(find.text('Times per week'));
    await tester.pump();
    await tester.tap(find.byTooltip('More times per week'));
    await tester.pump();
    expect(find.text('4 times per week'), findsOneWidget);
    await tester.tap(find.byTooltip('Save habit'));
    await tester.pumpAndSettle();
    final saved = habitRepo.habits.values.single;
    expect(saved.frequency, HabitFrequency.weekly);
    expect(saved.targetDaysPerWeek, 4);
    expect(find.text('0 wk streak'), findsOneWidget);
  });
}
