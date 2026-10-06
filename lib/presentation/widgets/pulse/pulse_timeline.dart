import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/services/pulse/timeline_builder.dart';

IconData iconForKind(TimelineKind kind) => switch (kind) {
  TimelineKind.sleep => Icons.bedtime_outlined,
  TimelineKind.wake => Icons.wb_sunny_outlined,
  TimelineKind.meal => Icons.restaurant_outlined,
  TimelineKind.water => Icons.water_drop_outlined,
  TimelineKind.workout => Icons.fitness_center_outlined,
  TimelineKind.focus => Icons.timer_outlined,
  TimelineKind.mood => Icons.sentiment_satisfied_outlined,
  TimelineKind.energy => Icons.bolt_outlined,
  TimelineKind.habit => Icons.track_changes_outlined,
  TimelineKind.task => Icons.check_box_outlined,
  TimelineKind.note => Icons.edit_note_outlined,
  TimelineKind.custom => Icons.circle_outlined,
};

/// The day as a chronological list: time, what happened, optional detail.
/// Dense and plain on purpose - it should read like a log, not a feed.
class PulseTimeline extends StatelessWidget {
  const PulseTimeline({super.key, required this.entries, this.onTapEntry});

  final List<TimelineEntry> entries;
  final ValueChanged<TimelineEntry>? onTapEntry;

  @override
  Widget build(BuildContext context) {
    final timed = entries.where((e) => e.time != null).toList();
    final untimed = entries.where((e) => e.time == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < timed.length; i++)
          _Row(
            entry: timed[i],
            isLast: i == timed.length - 1 && untimed.isEmpty,
            onTap: timed[i].isEditable && onTapEntry != null
                ? () => onTapEntry!(timed[i])
                : null,
          ),
        if (untimed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              'During the day',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          for (final e in untimed) _Row(entry: e, isLast: true),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.isLast, this.onTap});

  final TimelineEntry entry;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    final time = entry.time == null
        ? ''
        : DateFormat('HH:mm').format(entry.time!);
    return Semantics(
      label:
          '${entry.title}${entry.detail == null ? '' : ', ${entry.detail}'}'
          '${time.isEmpty ? '' : ' at $time'}',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  time,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Icon(iconForKind(entry.kind), size: 16, color: muted),
              const SizedBox(width: AppSpacing.smPlus),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: theme.textTheme.bodyMedium),
                    if (entry.detail != null)
                      Text(entry.detail!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 16, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
