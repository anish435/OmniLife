import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/goals_controller.dart';

import '../../support/fake_habit_repositories.dart';
import 'task_controller_test.dart' show FakeAuthRepository;

void main() {
  const user = AppUser(uid: 'u1', email: 'a@b.c');
  late FakeGoalRepository repo;
  late GoalsController controller;

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    final auth = AuthController(authRepository: FakeAuthRepository(user));
    auth.onInit();
    await Future<void>.delayed(Duration.zero);
    repo = FakeGoalRepository();
    controller = GoalsController(goalRepository: repo, authController: auth);
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(Get.reset);

  test(
    'createGoal persists title, target, date, habit and milestones',
    () async {
      final g = (await controller.createGoal(
        title: '  Run a 10k ',
        targetDescription: ' under an hour ',
        targetDate: DateTime(2026, 9, 1),
        linkedHabitId: 'h1',
        milestoneTitles: ['5k', '', '  8k  '],
      ))!;
      final stored = repo.goals[g.id]!;
      expect(stored.title, 'Run a 10k');
      expect(stored.targetDescription, 'under an hour');
      expect(stored.targetDate, DateTime(2026, 9, 1));
      expect(stored.linkedHabitId, 'h1');
      expect(stored.milestones.map((m) => m.title), ['5k', '8k']);
      expect(stored.milestones.every((m) => !m.done), isTrue);
      expect(controller.goalsForHabit('h1').single.id, g.id);
      expect(controller.goalsForHabit('other'), isEmpty);
    },
  );

  test('blank titles are rejected', () async {
    expect(await controller.createGoal(title: '   '), isNull);
    expect(controller.goals, isEmpty);
  });

  test('toggleMilestone persists and drives progress', () async {
    final g = (await controller.createGoal(
      title: 'G',
      milestoneTitles: ['a', 'b', 'c', 'd'],
    ))!;
    final updated = await controller.toggleMilestone(g.id, g.milestones[1].id);
    expect(updated!.doneMilestones, 1);
    expect(updated.progress, 0.25);
    expect(repo.goals[g.id]!.milestones[1].done, isTrue);
    expect(repo.goals[g.id]!.milestones[0].done, isFalse);

    for (final m in g.milestones) {
      if (!controller.goals.single.milestones
          .firstWhere((x) => x.id == m.id)
          .done) {
        await controller.toggleMilestone(g.id, m.id);
      }
    }
    expect(controller.goals.single.isComplete, isTrue);
    // Un-ticking works too.
    await controller.toggleMilestone(g.id, g.milestones[0].id);
    expect(controller.goals.single.isComplete, isFalse);
  });

  test('failed milestone save rolls the UI state back', () async {
    final g = (await controller.createGoal(
      title: 'G',
      milestoneTitles: ['a'],
    ))!;
    repo.failWrites = true;
    final r = await controller.toggleMilestone(g.id, g.milestones.single.id);
    expect(r, isNull);
    expect(controller.goals.single.milestones.single.done, isFalse);
    expect(controller.errorMessage.value, contains('Failed to update goal'));
  });

  test('failed create leaves no ghost goal', () async {
    repo.failWrites = true;
    expect(await controller.createGoal(title: 'G'), isNull);
    expect(controller.goals, isEmpty);
  });

  test('updateGoal can clear date and habit link', () async {
    final g = (await controller.createGoal(
      title: 'G',
      targetDate: DateTime(2026, 5, 5),
      linkedHabitId: 'h1',
    ))!;
    await controller.updateGoal(
      g.copyWith(clearTargetDate: true, clearLinkedHabit: true),
    );
    expect(repo.goals[g.id]!.targetDate, isNull);
    expect(repo.goals[g.id]!.linkedHabitId, isNull);
  });

  test('deleteGoal removes it from state and storage', () async {
    final g = (await controller.createGoal(title: 'G'))!;
    expect(await controller.deleteGoal(g.id), isTrue);
    expect(controller.goals, isEmpty);
    expect(repo.goals, isEmpty);
    expect(await controller.deleteGoal('missing'), isFalse);
  });

  test('loadGoals reads from the repository', () async {
    final g = (await controller.createGoal(title: 'G'))!;
    controller.goals.clear();
    await controller.loadGoals();
    expect(controller.goals.single.id, g.id);
  });
}
