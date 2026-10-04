import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';

/// Clean segmented filter chip with 8px radius and subtle selection states.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.badge,
    this.leadingDotColor,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final String? badge;
  final Color? leadingDotColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final hairline = theme.colorScheme.outline;
    final surface = theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(!isSelected),
          borderRadius: AppRadius.chipRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: isDark ? 0.22 : 0.14)
                  : surface,
              borderRadius: AppRadius.chipRadius,
              border: Border.all(
                color: isSelected ? primary : hairline,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingDotColor != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: leadingDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected ? primary : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
