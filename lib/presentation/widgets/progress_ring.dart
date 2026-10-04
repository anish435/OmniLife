import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';

/// Crisp circular progress ring with tabular numbers.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 54,
    this.strokeWidth = 5,
    this.color,
    this.backgroundColor,
    this.centerText,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final String? centerText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final track = backgroundColor ?? theme.colorScheme.outline.withValues(alpha: 0.3);
    final clamped = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: clamped,
            strokeWidth: strokeWidth,
            backgroundColor: track,
            color: accent,
            strokeCap: StrokeCap.round,
          ),
          if (centerText != null)
            Text(
              centerText!,
              style: AppTypography.tabular(
                TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
