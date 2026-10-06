import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/goal.dart';

/// Thin milestone progress bar plus "2 of 5 milestones" caption.
class MilestoneProgress extends StatelessWidget {
  const MilestoneProgress({super.key, required this.goal});

  final Goal goal;

  static String caption(Goal goal) {
    if (goal.totalMilestones == 0) return 'No milestones yet';
    return '${goal.doneMilestones} of ${goal.totalMilestones} milestones';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    return Semantics(
      label: 'Goal progress: ${caption(goal)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 4,
                backgroundColor: semantic.hairline,
                color: semantic.habits,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption(goal),
              style: theme.textTheme.labelSmall?.copyWith(
                color: semantic.mutedText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One goal in a list: title, linked habit, date, progress and tappable
/// milestone checkboxes (each tap persists).
class GoalTile extends StatelessWidget {
  const GoalTile({
    super.key,
    required this.goal,
    required this.onOpen,
    required this.onToggleMilestone,
    this.habitTitle,
    this.maxMilestones = 3,
  });

  final Goal goal;
  final String? habitTitle;
  final VoidCallback onOpen;
  final void Function(String milestoneId) onToggleMilestone;
  final int maxMilestones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final details = <String>[
      if (habitTitle != null) 'Habit: $habitTitle',
      if (goal.targetDate != null)
        'By ${DateFormat('MMM d, y').format(goal.targetDate!)}',
    ];
    final shown = goal.milestones.take(maxMilestones).toList();
    final hidden = goal.milestones.length - shown.length;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: semantic.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: goal.isComplete
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (goal.targetDescription.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  goal.targetDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.mutedText,
                  ),
                ),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  details.join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: semantic.tertiaryText,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.smPlus),
              MilestoneProgress(goal: goal),
              for (final m in shown)
                InkWell(
                  key: ValueKey('milestone-${m.id}'),
                  onTap: () => onToggleMilestone(m.id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Row(
                      children: [
                        Icon(
                          m.done
                              ? Icons.check_box_outlined
                              : Icons.check_box_outline_blank,
                          size: 20,
                          semanticLabel: m.done ? 'Done' : 'Not done',
                          color: m.done
                              ? theme.colorScheme.primary
                              : semantic.tertiaryText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            m.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: m.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: m.done ? semantic.mutedText : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (hidden > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '+$hidden more',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantic.tertiaryText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
