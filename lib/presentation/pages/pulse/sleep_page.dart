import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/services/pulse/sleep_analyzer.dart';
import '../../../domain/services/pulse/timeline_builder.dart';
import '../../controllers/pulse_controller.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pulse/pulse_quick_log.dart';
import '../../widgets/section_label.dart';

/// Sleep history built from one-tap Sleep and Wake entries. User-recorded,
/// not a medical measurement; times can be corrected afterwards.
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  final PulseController c = Get.find<PulseController>();

  @override
  void initState() {
    super.initState();
    c.loadInsights();
    c.refreshOpenSleep();
  }

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.responsiveGutter(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Obx(() {
              final data = c.insights.value;
              if (c.insightsLoading.value && data == null) {
                return const AppLoadingView(message: 'Loading sleep');
              }
              if (c.insightsError.value != null && data == null) {
                return AppErrorView(
                  message: c.insightsError.value!,
                  onRetry: c.loadInsights,
                );
              }
              final sessions = (data?.sessions ?? const <SleepSession>[])
                  .reversed
                  .take(30)
                  .toList();
              final summary = data?.sleep;
              return ListView(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 48),
                children: [
                  const SectionLabel(title: 'Right now'),
                  const PulseQuickLog(compact: true),
                  const SizedBox(height: AppSpacing.sectionGap),
                  if (summary != null && summary.nights > 0) ...[
                    const SectionLabel(title: 'Summary'),
                    _Summary(summary: summary),
                    const SizedBox(height: AppSpacing.sectionGap),
                  ],
                  const SectionLabel(title: 'Recent nights'),
                  if (sessions.isEmpty)
                    const EmptyState(
                      icon: Icons.bedtime_outlined,
                      message:
                          'No nights recorded yet. Tap Sleep at bedtime and '
                          'Wake in the morning; duration is calculated for you.',
                    )
                  else
                    for (final s in sessions) _SessionRow(session: s),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final SleepSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String time(int m) =>
        DateFormat('h:mm a').format(DateTime(2000, 1, 1, m ~/ 60, m % 60));
    final std = summary.bedtimeStdDevMinutes;
    final stats = <(String, String)>[
      ('Average', formatDuration(summary.averageDuration!)),
      if (summary.averageBedtime != null)
        ('Usual bedtime', time(summary.averageBedtime!)),
      if (std != null) ('Bedtime varies by', '${std.round()} min'),
      ('Nights recorded', '${summary.nights}'),
      if (summary.last30DayAverage != null &&
          summary.previous30DayAverage != null)
        (
          'Last 30 days vs before',
          '${formatDuration(summary.last30DayAverage!)} vs '
              '${formatDuration(summary.previous30DayAverage!)}',
        ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Wrap(
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
                Text(s.$2, style: theme.textTheme.bodyMedium),
              ],
            ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = session.duration.inMinutes / 60;
    final fraction = (hours / 10).clamp(0.0, 1.0);
    return InkWell(
      onTap: () => _edit(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                DateFormat('EEE d MMM').format(session.end),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                formatDuration(session.duration),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final c = Get.find<PulseController>();
    final start = await c.findEvent(session.startEventId);
    final end = await c.findEvent(session.endEventId);
    if (start == null || end == null || !context.mounted) return;

    Future<void> change(bool bedtime) async {
      final event = bedtime ? start : end;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(event.timestamp),
      );
      if (picked == null) return;
      final t = event.timestamp;
      await c.correctTime(
        event,
        DateTime(t.year, t.month, t.day, picked.hour, picked.minute),
      );
      await c.loadInsights();
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Night of ${DateFormat('EEE d MMM').format(session.start)}',
              ),
              subtitle: Text(
                '${DateFormat('h:mm a').format(session.start)} to '
                '${DateFormat('h:mm a').format(session.end)}, '
                '${formatDuration(session.duration)}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Correct bedtime'),
              onTap: () {
                Navigator.of(ctx).pop();
                change(true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Correct wake time'),
              onTap: () {
                Navigator.of(ctx).pop();
                change(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
