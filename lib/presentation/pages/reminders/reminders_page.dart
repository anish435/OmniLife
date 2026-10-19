import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/reminder_text.dart';
import '../../../domain/entities/reminder.dart';
import '../../controllers/reminders_controller.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/reminders/reminder_sheet.dart';
import '../../widgets/section_label.dart';

/// Reminders grouped as Upcoming, Repeating and Done. Add and edit happen in
/// a bottom sheet; delete is a swipe or the row menu, with Undo.
class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RemindersController>();
    final gutter = AppSpacing.responsiveGutter(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ReminderSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New reminder'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Obx(() {
              // Read reactive state first so Obx always tracks it.
              final all = c.reminders.toList();
              final loading = c.isLoading.value;
              final error = c.error.value;
              if (loading && all.isEmpty) {
                return const AppLoadingView(message: 'Loading reminders');
              }
              if (error != null && all.isEmpty) {
                return AppErrorView(message: error, onRetry: c.load);
              }
              if (all.isEmpty) {
                return EmptyState(
                  icon: Icons.alarm_outlined,
                  message:
                      'Nothing to remember yet. Add a reminder and we will '
                      'nudge you at the right time.',
                  actionLabel: 'Add a reminder',
                  onAction: () => ReminderSheet.show(context),
                );
              }
              final upcoming = c.upcoming;
              final repeating = c.repeating;
              final done = c.done;
              final now = c.now;
              return RefreshIndicator(
                onRefresh: c.load,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 96),
                  children: [
                    if (upcoming.isNotEmpty) ...[
                      const SectionLabel(title: 'Upcoming'),
                      for (final r in upcoming)
                        _ReminderRow(reminder: r, now: now, controller: c),
                      const SizedBox(height: AppSpacing.sectionGap),
                    ],
                    if (repeating.isNotEmpty) ...[
                      const SectionLabel(title: 'Repeating'),
                      for (final r in repeating)
                        _ReminderRow(reminder: r, now: now, controller: c),
                      const SizedBox(height: AppSpacing.sectionGap),
                    ],
                    if (done.isNotEmpty) ...[
                      const SectionLabel(title: 'Done'),
                      for (final r in done)
                        _ReminderRow(
                          reminder: r,
                          now: now,
                          controller: c,
                          isDone: true,
                        ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

enum _RowAction { edit, delete }

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.now,
    required this.controller,
    this.isDone = false,
  });

  final Reminder reminder;
  final DateTime now;
  final RemindersController controller;
  final bool isDone;

  Future<void> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await controller.delete(reminder);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Reminder deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.undoDelete(reminder),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dim = isDone || !reminder.enabled;
    final row = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => ReminderSheet.show(context, existing: reminder),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: dim ? muted : null,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reminder.enabled || isDone
                            ? describeReminderWhen(reminder, now)
                            : '${describeReminderWhen(reminder, now)} · Off',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isDone)
                Switch(
                  value: reminder.enabled,
                  onChanged: (v) => controller.setEnabled(reminder, v),
                ),
              PopupMenuButton<_RowAction>(
                tooltip: 'More options',
                onSelected: (a) {
                  switch (a) {
                    case _RowAction.edit:
                      ReminderSheet.show(context, existing: reminder);
                    case _RowAction.delete:
                      _delete(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _RowAction.edit, child: Text('Edit')),
                  PopupMenuItem(
                    value: _RowAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('reminder-${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.mdPlus),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.12),
          borderRadius: AppRadius.cardRadius,
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      ),
      onDismissed: (_) => _delete(context),
      child: row,
    );
  }
}
