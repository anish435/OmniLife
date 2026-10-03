import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/task.dart';

/// Clean row for rendering a Task within the calendar agenda.
///
/// Features:
/// - Distinct circular checkbox shape (vs rectangular left-bar event block)
/// - Strikethrough text animation on completion
/// - Due time and priority badge
class TaskAgendaRow extends StatelessWidget {
  const TaskAgendaRow({
    super.key,
    required this.task,
    required this.onToggle,
    this.onTap,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  String? get _formattedDueTime {
    if (task.dueDate == null) return null;
    final dt = task.dueDate!;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (h == '00' && m == '00') return null;
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final borderColor = isDark ? const Color(0xFF33383F) : const Color(0xFFDADFE3);

    final dueTime = _formattedDueTime;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            // Circular checkbox
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onToggle();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.completed ? primary : Colors.transparent,
                  border: Border.all(
                    color: task.completed ? primary : borderColor,
                    width: 1.5,
                  ),
                ),
                child: task.completed
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // Title & indicators
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: task.completed
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (dueTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Due $dueTime',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (task.priority == TaskPriority.high)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HIGH',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
