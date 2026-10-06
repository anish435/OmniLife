import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_spacing.dart';
import '../../controllers/goals_controller.dart';
import '../../controllers/habits_controller.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/habits/goal_tile.dart';
import '../../widgets/section_label.dart';
import 'create_goal_sheet.dart';
import 'create_habit_sheet.dart';
import 'habit_card.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HabitsController>();
    final goals = GoalsController.ensureRegistered();

    Future<void> refresh() async {
      await controller.loadHabits();
      await goals.loadGoals();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Habits & Goals')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New habit',
        onPressed: () => CreateHabitSheet.show(context),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final habits = controller.habits;
        if (controller.isLoading.value && habits.isEmpty) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final error = controller.errorMessage.value;
        if (error != null && habits.isEmpty) {
          return AppErrorView(message: error, onRetry: refresh);
        }

        final theme = Theme.of(context);
        final goalList = goals.goals.toList();

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.section + 56,
            ),
            children: [
              const SectionLabel(title: 'Habits'),
              if (habits.isEmpty)
                AppEmptyView(
                  message: 'No habits yet',
                  subtitle: 'Start building momentum today.',
                  icon: Icons.track_changes_outlined,
                  actionLabel: 'New Habit',
                  onAction: () => CreateHabitSheet.show(context),
                )
              else
                for (final habit in habits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: HabitCard(key: ValueKey(habit.id), habit: habit),
                  ),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionLabel(
                title: 'Goals',
                trailing: TextButton.icon(
                  key: const ValueKey('new-goal'),
                  onPressed: () => CreateGoalSheet.show(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New goal'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              if (goals.isLoading.value && goalList.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (goals.errorMessage.value != null && goalList.isEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goals.errorMessage.value!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: goals.loadGoals,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else if (goalList.isEmpty)
                AppEmptyView(
                  message: 'No goals yet',
                  subtitle: 'Link a goal to a habit and track it milestone by milestone.',
                  icon: Icons.flag_outlined,
                  actionLabel: 'New Goal',
                  onAction: () => CreateGoalSheet.show(context),
                )
              else
                for (final g in goalList)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GoalTile(
                      key: ValueKey('goal-${g.id}'),
                      goal: g,
                      habitTitle: habits
                          .firstWhereOrNull((h) => h.id == g.linkedHabitId)
                          ?.title,
                      onOpen: () =>
                          CreateGoalSheet.show(context, goalToEdit: g),
                      onToggleMilestone: (id) =>
                          goals.toggleMilestone(g.id, id),
                    ),
                  ),
            ],
          ),
        );
      }),
    );
  }
}
