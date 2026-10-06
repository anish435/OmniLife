import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../domain/focus/focus_timer.dart';
import '../../controllers/focus_controller.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/section_label.dart';
import 'focus_media_panels.dart';

/// Focus mode: a pomodoro timer with ambient sound, optional looping video
/// and a short history of finished sessions.
class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  late final FocusController controller = Get.find<FocusController>();
  Worker? _messageWorker;

  @override
  void initState() {
    super.initState();
    _messageWorker = ever<String?>(controller.message, (text) {
      if (text == null || !mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
      controller.message.value = null;
    });
  }

  @override
  void dispose() {
    _messageWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              AppSpacing.section + 56,
            ),
            children: [
              _TimerCard(controller: controller),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionLabel(title: 'Ambient sound'),
              AmbientSoundPanel(controller: controller),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionLabel(title: 'Background video'),
              VideoPanel(controller: controller),
              const SizedBox(height: AppSpacing.sectionGap),
              _History(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

String formatClock(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.controller});

  final FocusController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.mdPlus),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: semantic.hairline),
      ),
      child: Obx(() {
        final s = controller.timerState.value;
        final left = controller.remaining.value;
        final total = s.segmentDuration.inMilliseconds;
        final progress = s.phase == FocusPhase.completed
            ? 1.0
            : total <= 0
            ? 0.0
            : (1 - left.inMilliseconds / total).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _phaseLabel(s),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: semantic.tertiaryText,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label:
                  'Time remaining ${left.inMinutes} minutes '
                  '${left.inSeconds % 60} seconds',
              child: ExcludeSemantics(
                child: Text(
                  formatClock(left),
                  key: const Key('focus_clock'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 52,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.smPlus),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: s.phase == FocusPhase.idle ? 0 : progress,
                minHeight: 3,
                backgroundColor: semantic.hairline,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (s.phase == FocusPhase.idle) ...[
              _LengthPicker(
                label: 'Focus',
                options: const [15, 25, 45, 50],
                selected: s.focusDuration.inMinutes,
                onSelected: controller.setFocusMinutes,
              ),
              const SizedBox(height: AppSpacing.sm),
              _LengthPicker(
                label: 'Break',
                options: const [5, 10, 15],
                selected: s.breakDuration.inMinutes,
                onSelected: controller.setBreakMinutes,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _Controls(controller: controller, state: s),
          ],
        );
      }),
    );
  }

  String _phaseLabel(FocusTimerState s) {
    switch (s.phase) {
      case FocusPhase.idle:
        return 'READY';
      case FocusPhase.running:
        return 'FOCUS';
      case FocusPhase.paused:
        return s.segment == FocusSegment.focus
            ? 'FOCUS PAUSED'
            : 'BREAK PAUSED';
      case FocusPhase.onBreak:
        return 'BREAK';
      case FocusPhase.completed:
        return 'SESSION COMPLETE';
    }
  }
}

class _LengthPicker extends StatelessWidget {
  const _LengthPicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            runSpacing: 6,
            children: [
              for (final m in options)
                AppChip(
                  label: '$m min',
                  isSelected: m == selected,
                  onSelected: (_) => onSelected(m),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.state});

  final FocusController controller;
  final FocusTimerState state;

  @override
  Widget build(BuildContext context) {
    final buttons = switch (state.phase) {
      FocusPhase.idle => [
        PrimaryButton(
          label: 'Start focus',
          icon: Icons.play_arrow_rounded,
          isFullWidth: true,
          onPressed: controller.start,
        ),
      ],
      FocusPhase.running => [
        SecondaryButton(
          label: 'Pause',
          icon: const Icon(Icons.pause_rounded, size: 18),
          onPressed: controller.pause,
        ),
        TextButton(onPressed: controller.stop, child: const Text('Stop')),
      ],
      FocusPhase.paused => [
        PrimaryButton(
          label: 'Resume',
          icon: Icons.play_arrow_rounded,
          onPressed: controller.resume,
        ),
        TextButton(
          onPressed: state.segment == FocusSegment.rest
              ? controller.skipBreak
              : controller.stop,
          child: Text(
            state.segment == FocusSegment.rest ? 'Skip break' : 'Stop',
          ),
        ),
      ],
      FocusPhase.onBreak => [
        SecondaryButton(
          label: 'Pause',
          icon: const Icon(Icons.pause_rounded, size: 18),
          onPressed: controller.pause,
        ),
        TextButton(
          onPressed: controller.skipBreak,
          child: const Text('Skip break'),
        ),
      ],
      FocusPhase.completed => [
        PrimaryButton(
          label: 'Start break',
          icon: Icons.free_breakfast_outlined,
          onPressed: controller.startBreak,
        ),
        TextButton(onPressed: controller.skipBreak, child: const Text('Done')),
      ],
    };
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: buttons,
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.controller});

  final FocusController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Obx(() {
      final today = controller.todaySessions;
      final todayMinutes = controller.todayMinutes;
      final weekMinutes = controller.weekMinutes;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel(title: 'History'),
          Row(
            children: [
              Expanded(
                child: _Total(label: 'Today', minutes: todayMinutes),
              ),
              const SizedBox(width: AppSpacing.smPlus),
              Expanded(
                child: _Total(label: 'This week', minutes: weekMinutes),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smPlus),
          if (controller.isLoading.value && controller.sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (controller.errorMessage.value != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                children: [
                  Text(
                    controller.errorMessage.value!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: controller.loadSessions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (today.isEmpty)
            const EmptyState(
              icon: Icons.timer_outlined,
              message: 'No focus sessions yet today.\nStart one above.',
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: semantic.hairline),
                borderRadius: AppRadius.cardRadius,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < today.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: semantic.hairline),
                    ListTile(
                      dense: true,
                      title: Text('${today[i].focusedMinutes} min focus'),
                      subtitle: Text(
                        DateFormat('HH:mm').format(today[i].startedAt),
                      ),
                      leading: Icon(
                        Icons.check_circle_outline,
                        color: semantic.success,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.minutes});

  final String label;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final text = hours > 0 ? '${hours}h ${rest}m' : '${rest}m';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smPlus),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: semantic.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: semantic.mutedText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
