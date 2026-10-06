import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/services/pulse/day_replay.dart';
import '../../../domain/services/pulse/timeline_builder.dart';

/// "Your day": a factual summary of one day. Built only from what the user
/// recorded; the sentence on top is rule-based over counts.
class DayReplayCard extends StatelessWidget {
  const DayReplayCard({super.key, required this.replay});

  final DayReplay replay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = <(String, String)>[
      if (replay.wakeTime != null)
        ('Wake', DateFormat('HH:mm').format(replay.wakeTime!)),
      if (replay.sleepDuration != null)
        ('Sleep', formatDuration(replay.sleepDuration!)),
      if (replay.focusSessions > 0)
        (
          'Focus',
          '${replay.focusSessions} session${replay.focusSessions == 1 ? '' : 's'}',
        ),
      if (replay.tasksCompleted > 0)
        ('Tasks', '${replay.tasksCompleted} completed'),
      if (replay.workouts > 0) ('Workout', '${replay.workouts}'),
      if (replay.habitsDone > 0) ('Habits', '${replay.habitsDone} done'),
      if (replay.waterMl > 0) ('Water', '${replay.waterMl} ml'),
      if (replay.averageMood != null)
        ('Mood', '${replay.averageMood!.toStringAsFixed(1)} / 5'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(replay.summary, style: theme.textTheme.titleSmall),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.smPlus,
              children: [
                for (final s in stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.$1, style: theme.textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        s.$2,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
