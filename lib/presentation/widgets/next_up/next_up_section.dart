import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/insights/prefs_next_up_store.dart';
import '../../../domain/entities/life_event.dart';
import '../../../domain/insights/next_up.dart';
import '../../controllers/next_up_controller.dart';
import '../../controllers/pulse_controller.dart';
import '../section_label.dart';

/// "Next up": up to three short lines about what is left today. Hides
/// itself when there is nothing useful to say, never repeats a hint the
/// user dismissed or acted on, and is on-screen only (no notifications).
class NextUpSection extends StatefulWidget {
  const NextUpSection({super.key, this.controller});

  /// Injected in tests; otherwise resolved from GetX.
  final NextUpController? controller;

  @override
  State<NextUpSection> createState() => _NextUpSectionState();
}

class _NextUpSectionState extends State<NextUpSection> {
  late final NextUpController _c;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c =
        widget.controller ??
        (Get.isRegistered<NextUpController>()
            ? Get.find<NextUpController>()
            : Get.put(NextUpController(store: PrefsNextUpStore())));
    unawaited(_c.ensureLoaded());
    _loadToday();
    // Time-based hints (a three hour water gap) need a gentle re-check.
    _timer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _c.tick.value++,
    );
  }

  void _loadToday() {
    if (!Get.isRegistered<PulseController>()) return;
    final pulse = Get.find<PulseController>();
    if (pulse.dayView.value == null && pulse.uid != null) {
      pulse.goToday();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tap(NextUpItem item) async {
    switch (item.action) {
      case NextUpAction.openTasks:
        unawaited(_c.acted(item.id));
        Get.toNamed(AppRoutes.tasks);
      case NextUpAction.openHabits:
        unawaited(_c.acted(item.id));
        Get.toNamed(AppRoutes.habits);
      case NextUpAction.openReminders:
        unawaited(_c.acted(item.id));
        Get.toNamed(AppRoutes.reminders);
      case NextUpAction.logWater:
        await _log(item, LifeEventType.water, 'Water logged');
      case NextUpAction.logMeal:
        await _log(item, LifeEventType.meal, 'Meal logged');
    }
  }

  Future<void> _log(NextUpItem item, LifeEventType type, String done) async {
    if (!Get.isRegistered<PulseController>()) return;
    final pulse = Get.find<PulseController>();
    final result = await pulse.log(type);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (result == null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(pulse.error.value ?? 'That did not save.')),
      );
      return;
    }
    unawaited(_c.acted(item.id));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(done),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => pulse.undo(result.event),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = _c.items;
      if (items.isEmpty) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel(title: 'Next up'),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: context.semanticColors.hairline,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: context.semanticColors.hairline,
                      ),
                    _NextUpRow(
                      item: items[i],
                      onTap: () => _tap(items[i]),
                      onDismiss: () => _c.dismiss(items[i].id),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _NextUpRow extends StatelessWidget {
  const _NextUpRow({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  final NextUpItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minRowHeight),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    item.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              if (item.actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    item.actionLabel!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.semanticColors.tertiaryText,
                  ),
                ),
              IconButton(
                tooltip: 'Hide for today',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
