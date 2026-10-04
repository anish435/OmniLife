import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Standard list row with guaranteed min height >= 48px, hairline divider,
/// and subtle press response.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.borderBottom = true,
    this.leftIndicatorColor,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool borderBottom;
  final Color? leftIndicatorColor;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.colorScheme.outline;

    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.minRowHeight),
      child: Padding(
        padding: contentPadding,
        child: Row(
          children: [
            if (leftIndicatorColor != null) ...[
              Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: leftIndicatorColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: AppSpacing.smPlus),
            ],
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.smPlus),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.smPlus),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (borderBottom) {
      content = Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: hairline, width: 0.5)),
        ),
        child: content,
      );
    }

    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    return content;
  }
}
