import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Compact metric tile for dashboards and summaries.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.sublabel,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final String? sublabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surfaceContainerHighest;
    final hairline = theme.colorScheme.outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: hairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: AppTypography.sectionLabel(
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  if (icon != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (iconColor ?? theme.colorScheme.primary)
                            .withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: iconColor ?? theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: AppTypography.tabular(
                  theme.textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (sublabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  sublabel!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
