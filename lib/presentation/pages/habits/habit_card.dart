import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/usecases/habits/habit_streaks.dart';
import '../../controllers/goals_controller.dart';
import '../../controllers/habits_controller.dart';
import '../../widgets/calendar/calendar_colors.dart';
import '../../widgets/habits/animated_check_circle.dart';
import '../../widgets/habits/goal_tile.dart';
import 'habit_detail_page.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.habit});

  final Habit habit;

  /// Human label for the current streak, in the unit the habit counts in.
  static String streakLabel(Habit habit) {
    final n = habit.currentStreak;
    switch (habit.frequency) {
      case HabitFrequency.weekly:
        return '$n wk streak';
      case HabitFrequency.specificDays:
        return '$n in a row';
      case HabitFrequency.daily:
        return '$n day streak';
    }
  }

  static Color colorFor(BuildContext context, Habit habit) =>
      habit.colorTag != 'default'
      ? CalendarColors.getTag(habit.colorTag).color
      : context.semanticColors.habits;

  /// Shows a confirmation after a day is toggled, never overlapping a prior one.
  static Future<void> toggleDay(
    BuildContext context,
    HabitsController controller,
    Habit habit,
    DateTime date,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await controller.toggleHabitLog(habit.id, date);
    if (result == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not update habit')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final controller = Get.find<HabitsController>();
    final color = colorFor(context, habit);

    final today = controller.today;
    final last7Days = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day - (6 - index)),
    );
    final todayKey = HabitStreaks.dateKey(today);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: semantic.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => HabitDetailPage.open(context, habit.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        habit.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      streakLabel(habit),
                      key: ValueKey('streak-${habit.id}'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: habit.currentStreak > 0
                            ? theme.colorScheme.primary
                            : semantic.mutedText,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (habit.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    habit.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: semantic.mutedText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.smPlus),
                Row(
                  children: [
                    for (final date in last7Days)
                      Expanded(
                        child: Obx(() {
                          final done = controller.isHabitCompleted(
                            habit.id,
                            date,
                          );
                          final key = HabitStreaks.dateKey(date);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('E').format(date).substring(0, 1),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: key == todayKey
                                      ? theme.colorScheme.primary
                                      : semantic.tertiaryText,
                                  fontWeight: key == todayKey
                                      ? FontWeight.w700
                                      : null,
                                ),
                              ),
                              AnimatedCheckCircle(
                                key: ValueKey('day-${habit.id}-$key'),
                                completed: done,
                                fillColor: color,
                                highlightToday: key == todayKey,
                                semanticLabel:
                                    '${habit.title}, '
                                    '${DateFormat('EEEE d MMMM').format(date)}',
                                onTap: () =>
                                    toggleDay(context, controller, habit, date),
                              ),
                            ],
                          );
                        }),
                      ),
                  ],
                ),
                _LinkedGoals(habitId: habit.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkedGoals extends StatelessWidget {
  const _LinkedGoals({required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<GoalsController>()) return const SizedBox.shrink();
    final goalsController = Get.find<GoalsController>();
    return Obx(() {
      final goals = goalsController.goalsForHabit(habitId);
      if (goals.isEmpty) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final semantic = context.semanticColors;
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.smPlus),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final g in goals)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goal: ${g.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: semantic.mutedText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    MilestoneProgress(goal: g),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}
