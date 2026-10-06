import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/life_event.dart';
import '../../../domain/services/pulse/timeline_builder.dart';
import '../../../domain/usecases/pulse/pulse_service.dart';
import '../../controllers/pulse_controller.dart';

/// "Log a moment": every control records immediately and confirms with an
/// Undo, no form first. Detail can be added later from the timeline.
///
/// [compact] shows the most common moments (used on the dashboard);
/// the full set lives on the Pulse page.
class PulseQuickLog extends StatelessWidget {
  const PulseQuickLog({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PulseController>();
    return Obx(() {
      final asleep = c.openSleep.value;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (asleep == null)
            _LogButton(
              icon: Icons.bedtime_outlined,
              label: 'Sleep',
              onTap: () => _handle(context, c.startSleep()),
            )
          else
            _LogButton(
              icon: Icons.wb_sunny_outlined,
              label: 'Wake',
              emphasised: true,
              caption: 'Asleep since ${_time(asleep.timestamp)}',
              onTap: () => _handle(context, c.wake()),
            ),
          _LogButton(
            icon: Icons.water_drop_outlined,
            label: 'Water',
            onTap: () => _handle(context, c.log(LifeEventType.water)),
          ),
          _LogButton(
            icon: Icons.restaurant_outlined,
            label: 'Meal',
            onTap: () => _handle(context, c.log(LifeEventType.meal)),
          ),
          _LogButton(
            icon: Icons.fitness_center_outlined,
            label: 'Workout',
            onTap: () => _handle(context, c.log(LifeEventType.workout)),
          ),
          _ChoiceButton(
            icon: Icons.sentiment_satisfied_outlined,
            label: 'Mood',
            choices: const {'Good': 4, 'Okay': 3, 'Low': 2},
            onChoose: (score) => _handle(
              context,
              c.log(LifeEventType.mood, metadata: {'score': score}),
            ),
          ),
          _ChoiceButton(
            icon: Icons.bolt_outlined,
            label: 'Energy',
            choices: const {'High': 4, 'Okay': 3, 'Low': 2},
            onChoose: (level) => _handle(
              context,
              c.log(LifeEventType.energy, metadata: {'level': level}),
            ),
          ),
          if (!compact) ...[
            _LogButton(
              icon: Icons.timer_outlined,
              label: 'Focus',
              onTap: () => _handle(context, c.log(LifeEventType.focus)),
            ),
            _LogButton(
              icon: Icons.edit_note_outlined,
              label: 'Note',
              onTap: () => _addNote(context, c),
            ),
          ],
        ],
      );
    });
  }

  Future<void> _addNote(BuildContext context, PulseController c) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note a moment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          decoration: const InputDecoration(hintText: 'What happened?'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    await _handle(
      context,
      c.log(LifeEventType.note, metadata: {'label': text.trim()}),
    );
  }

  static String _time(DateTime t) => DateFormat('h:mm a').format(t);

  /// Waits for the save, then confirms with Undo (or reports a failure).
  static Future<void> _handle(
    BuildContext context,
    Future<QuickLogResult?> pending,
  ) async {
    final c = Get.find<PulseController>();
    final result = await pending;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (result == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(c.error.value ?? 'That did not save.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(confirmationText(result)),
        duration: const Duration(seconds: 5),
        action: result.alreadyAsleep
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () => c.undo(result.event),
              ),
      ),
    );
  }

  /// The confirmation shown after a tap, e.g. "Wake logged · Slept 7h 36m".
  static String confirmationText(QuickLogResult r) {
    if (r.alreadyAsleep) {
      return 'Already sleeping since ${_time(r.event.timestamp)}';
    }
    final e = r.event;
    final at = _time(e.timestamp);
    switch (e.type) {
      case LifeEventType.sleepStart:
        return 'Sleep logged · $at';
      case LifeEventType.wake:
        return r.sleepDuration == null
            ? 'Wake logged · $at'
            : 'Wake logged · Slept ${formatDuration(r.sleepDuration!)}';
      case LifeEventType.water:
        return 'Water logged · ${e.metadata['ml'] ?? 250} ml';
      case LifeEventType.meal:
        final kind = e.metadata['kind'] as String?;
        return kind == null
            ? 'Meal logged · $at'
            : '${kind[0].toUpperCase()}${kind.substring(1)} logged · $at';
      case LifeEventType.mood:
        return 'Mood logged · ${moodLabel(e.moodScore ?? 3)}';
      case LifeEventType.energy:
        return 'Energy logged · ${energyLabel(e.energyLevel ?? 3)}';
      case LifeEventType.workout:
        return 'Workout logged · $at';
      case LifeEventType.focus:
        return 'Focus logged · $at';
      default:
        return 'Logged · $at';
    }
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final bool emphasised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: caption == null ? 'Log $label' : '$label. $caption',
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
          ),
          side: BorderSide(color: emphasised ? scheme.primary : scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (caption != null)
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
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

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.choices,
    required this.onChoose,
  });

  final IconData icon;
  final String label;
  final Map<String, int> choices;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      tooltip: 'Log $label',
      onSelected: onChoose,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      itemBuilder: (_) => [
        for (final e in choices.entries)
          PopupMenuItem(value: e.value, child: Text(e.key)),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
