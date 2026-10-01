import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// Branded "Continue with Google" button with the authentic 4-color Google G icon.
///
/// Follows Material 3 styling and OmniLife design tokens, adapting smoothly
/// to both light and dark themes.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        backgroundColor: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surface,
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 13,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mediumRadius,
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoogleLogo(size: 20),
                const SizedBox(width: AppSpacing.md),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Renders the official 4-color Google 'G' mark cleanly via canvas paths.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Blue
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.48, 23.675, 10.73, 23.55, 10.01)
      ..lineTo(12.0, 10.01)
      ..lineTo(12.0, 14.65)
      ..lineTo(18.59, 14.65)
      ..cubicTo(18.3, 16.14, 17.44, 17.41, 16.14, 18.28)
      ..lineTo(16.14, 21.36)
      ..lineTo(20.07, 21.36)
      ..cubicTo(22.37, 19.24, 23.745, 16.08, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.96, 22.92, 19.98, 21.05)
      ..lineTo(16.14, 18.06)
      ..cubicTo(15.07, 18.78, 13.68, 19.23, 12.0, 19.23)
      ..cubicTo(8.87, 19.23, 6.22, 17.11, 5.27, 14.28)
      ..lineTo(1.22, 14.28)
      ..lineTo(1.22, 17.42)
      ..cubicTo(3.23, 21.41, 7.35, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.27, 14.29)
      ..cubicTo(5.02, 13.57, 4.89, 12.8, 4.89, 12.0)
      ..cubicTo(4.89, 11.2, 5.03, 10.43, 5.27, 9.71)
      ..lineTo(5.27, 6.57)
      ..lineTo(1.22, 6.57)
      ..cubicTo(0.44, 8.12, 0.0, 9.99, 0.0, 12.0)
      ..cubicTo(0.0, 14.01, 0.44, 15.88, 1.22, 17.43)
      ..lineTo(5.27, 14.29)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.07, 3.08)
      ..cubicTo(17.95, 1.17, 15.23, 0.0, 12.0, 0.0)
      ..cubicTo(7.35, 0.0, 3.23, 2.59, 1.22, 6.58)
      ..lineTo(5.27, 9.72)
      ..cubicTo(6.22, 6.89, 8.87, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
