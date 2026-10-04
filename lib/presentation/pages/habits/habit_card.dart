import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/habit.dart';
import '../../controllers/habits_controller.dart';
import '../../widgets/calendar/calendar_colors.dart';
import 'create_habit_sheet.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<HabitsController>();
    final tag = CalendarColors.getTag(habit.colorTag);

    // Calculate last 7 days
    final today = DateTime.now();
    final last7Days = List.generate(7, (index) => today.subtract(Duration(days: 6 - index)));

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => CreateHabitSheet.show(context, habitToEdit: habit),
        child: Column(
          children: [
            if (habit.colorTag != 'default')
              Container(
                height: 4,
                width: double.infinity,
                color: tag.color,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 16,
                              color: habit.currentStreak > 0 ? Colors.orange : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${habit.currentStreak}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: habit.currentStreak > 0 ? Colors.orange : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (habit.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      habit.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: last7Days.map((date) {
                      return Obx(() {
                        final isCompleted = controller.isHabitCompleted(habit.id, date);
                        final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(today);
                        
                        return GestureDetector(
                          onTap: () => controller.toggleHabitLog(habit.id, date),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('E').format(date).substring(0, 1),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isToday 
                                      ? theme.colorScheme.primary 
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: isToday ? FontWeight.bold : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isCompleted 
                                      ? (habit.colorTag != 'default' ? tag.color : theme.colorScheme.primary)
                                      : theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                  border: isToday && !isCompleted ? Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                    width: 2,
                                  ) : null,
                                ),
                                child: isCompleted 
                                    ? Icon(
                                        Icons.check, 
                                        size: 18, 
                                        color: habit.colorTag != 'default' ? tag.onColor : theme.colorScheme.onPrimary,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        );
                      });
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
