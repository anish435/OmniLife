import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// Clean module grid tile with module-colored icon tint, item count or subtitle,
/// and no noisy "ACTIVE" badges.
class ModuleTile extends StatelessWidget {
  const ModuleTile({
    super.key,
    required this.name,
    required this.icon,
    required this.accentColor,
    this.countLabel,
    this.onTap,
  });

  final String name;
  final IconData icon;
  final Color accentColor;
  final String? countLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 20,
                        color: accentColor,
                      ),
                    ),
                  ),
                  if (countLabel != null)
                    Text(
                      countLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.smPlus),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
