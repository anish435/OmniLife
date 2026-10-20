import 'package:flutter/material.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/assistant/chat_message.dart';
import '../../controllers/assistant_controller.dart';

/// Renders a single tool action card (e.g. task added, expense logged, reminder set)
/// with Undo, Confirm or Cancel action triggers.
class AssistantActionCard extends StatelessWidget {
  const AssistantActionCard({
    super.key,
    required this.card,
    required this.controller,
  });

  final ActionCard card;
  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>();
    final muted = semantic?.mutedText ?? theme.colorScheme.onSurfaceVariant;
    final struck =
        card.status == CardStatus.undone || card.status == CardStatus.cancelled;

    Widget? actions;
    switch (card.status) {
      case CardStatus.done:
        if (card.canUndo) {
          actions = TextButton(
            onPressed: () => controller.undo(card.id),
            child: const Text('Undo'),
          );
        }
      case CardStatus.awaitingConfirm:
        actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => controller.cancel(card.id),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => controller.confirm(card.id),
              child: const Text('Delete'),
            ),
          ],
        );
      case CardStatus.undone:
      case CardStatus.cancelled:
        break;
    }

    final status = switch (card.status) {
      CardStatus.undone => 'Undone',
      CardStatus.cancelled => 'Cancelled',
      _ => null,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.smPlus,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                status == null ? card.label : '${card.label} ($status)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: struck ? muted : null,
                  decoration: struck ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
          ?actions,
        ],
      ),
    );
  }
}
