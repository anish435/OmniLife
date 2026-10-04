import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Standard "nothing here yet" placeholder for empty lists/collections.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.message,
    this.icon,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    // Fix duplicate plus sign: if actionLabel already has '+ ', clean it for icon button
    String? cleanLabel = actionLabel;
    bool hasPlus = false;
    if (cleanLabel != null && cleanLabel.startsWith('+')) {
      hasPlus = true;
      cleanLabel = cleanLabel.replaceFirst(RegExp(r'^\+\s*'), '');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                child: Icon(
                  icon ?? Icons.inbox_outlined,
                  color: secondary.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.smPlus),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(hasPlus ? Icons.add : Icons.arrow_forward, size: 16),
              label: Text(cleanLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
