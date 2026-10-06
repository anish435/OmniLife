import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/usecases/habits/habit_streaks.dart';
import '../../controllers/goals_controller.dart';
import '../../controllers/habits_controller.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/habits/animated_check_circle.dart';
import '../../widgets/habits/goal_tile.dart';
import '../../widgets/habits/habit_heatmap.dart';
import '../../widgets/section_label.dart';
import 'create_goal_sheet.dart';
import 'create_habit_sheet.dart';
import 'habit_card.dart';

/// Everything about one habit: streaks, the 365-day heatmap and its goals.
class HabitDetailPage extends StatelessWidget {
  const HabitDetailPage({super.key, required this.habitId});

  final String habitId;

  static Future<void> open(BuildContext context, String habitId) {
    GoalsController.ensureRegistered();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HabitDetailPage(habitId: habitId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HabitsController>();
    final goals = GoalsController.ensureRegistered();

    return Obx(() {
      final habit = controller.habits.firstWhereOrNull((h) => h.id == habitId);
      if (habit == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Habit')),
          body: const AppEmptyView(
            message: 'This habit no longer exists',
            icon: Icons.track_changes_outlined,
          ),
        );
      }
      final theme = Theme.of(context);
      final semantic = context.semanticColors;
      final color = HabitCard.colorFor(context, habit);
      final today = controller.today;
      final todayDone = controller.isHabitCompleted(habitId, today);
      final completed = controller.completedDatesFor(habitId);
      final habitGoals = goals.goalsForHabit(habitId);
      final unit = habit.frequency == HabitFrequency.weekly ? 'week' : 'day';
      final todayKey = HabitStreaks.dateKey(today);

      return Scaffold(
        appBar: AppBar(
          title: Text(habit.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Edit habit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  CreateHabitSheet.show(context, habitToEdit: habit),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.section + 56,
          ),
          children: [
            if (habit.description.isNotEmpty) ...[
              Text(
                habit.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: semantic.mutedText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Current',
                    value: '${habit.currentStreak}',
                    unit: unit,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Longest',
                    value: '${habit.longestStreak}',
                    unit: unit,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Last 365',
                    value: '${_doneInWindow(completed, today)}',
                    unit: 'day',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                AnimatedCheckCircle(
                  key: ValueKey('detail-today-$todayKey'),
                  completed: todayDone,
                  size: 36,
                  fillColor: color,
                  semanticLabel: 'Mark ${habit.title} done today',
                  onTap: () =>
                      HabitCard.toggleDay(context, controller, habit, today),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    todayDone ? 'Done today' : 'Not done today',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const SectionLabel(title: 'Consistency'),
            HabitHeatmap(
              completedDates: completed,
              today: today,
              longestStreak: habit.longestStreak,
              streakUnit: unit,
              color: color,
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            SectionLabel(
              title: 'Goals',
              trailing: TextButton.icon(
                key: const ValueKey('add-goal-for-habit'),
                onPressed: () =>
                    CreateGoalSheet.show(context, initialHabitId: habitId),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add goal'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            if (habitGoals.isEmpty)
              Text(
                'No goals linked to this habit yet. A goal turns this routine '
                'into something with a finish line.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: semantic.mutedText,
                ),
              )
            else
              for (final g in habitGoals)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: GoalTile(
                    goal: g,
                    habitTitle: habit.title,
                    onOpen: () => CreateGoalSheet.show(context, goalToEdit: g),
                    onToggleMilestone: (id) => goals.toggleMilestone(g.id, id),
                  ),
                ),
          ],
        ),
      );
    });
  }

  static int _doneInWindow(Set<String> completed, DateTime today) {
    final todayNo = HabitStreaks.dayNumberOfDate(today);
    var n = 0;
    for (final k in completed) {
      final d = HabitStreaks.dayNumberOf(k);
      if (d != null && d <= todayNo && d > todayNo - 365) n++;
    }
    return n;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final unitText = int.tryParse(value) == 1 ? unit : '${unit}s';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: semantic.tertiaryText,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Semantics(
          label: '$label $value $unitText',
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: ' $unitText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: semantic.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
