import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_semantic_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../domain/entities/task.dart';

/// Artisanal row/card representing a single [Task].
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  Color _priorityColor(BuildContext context, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppColors.error;
      case TaskPriority.medium:
        return context.semanticColors.warning;
      case TaskPriority.low:
        return context.semanticColors.moduleTasks;
    }
  }

  String _formatDueDate(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(due.year, due.month, due.day);

    final diff = taskDay.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < -1) return '${-diff}d overdue';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[due.month - 1]} ${due.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final surface = theme.colorScheme.surface;
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.completed;

    final priorityColor = _priorityColor(context, task.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: task.completed ? hairline.withValues(alpha: 0.4) : hairline,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular checkbox
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: task.completed
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.completed
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: task.completed
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: task.completed
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),

                    // Metadata row: dot + priority + tabular due date
                    Row(
                      children: [
                        // Priority dot + text
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          task.priority.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: priorityColor,
                          ),
                        ),

                        // Due Date
                        if (task.dueDate != null) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDueDate(task.dueDate!),
                            style: AppTypography.tabular(
                              TextStyle(
                                fontSize: 11,
                                fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
                                color: isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Contextual delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                onPressed: onDelete,
                tooltip: 'Delete task',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
