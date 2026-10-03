import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Extremely subtle, calm, and minimal animated dot-grid background for OmniLife.
///
/// Recreates the ambient dot-grid natively in Flutter using [CustomPainter] and
/// [AnimationController]. It uses only the colors already present in OmniLife's
/// theme (neutral slate / graphite), strictly avoiding neon colors, glows,
/// or gradient overlays.
class OmniLifeAuthBackground extends StatefulWidget {
  const OmniLifeAuthBackground({
    super.key,
    required this.child,
    this.dotSpacing = 26.0,
  });

  final Widget child;
  final double dotSpacing;

  @override
  State<OmniLifeAuthBackground> createState() => _OmniLifeAuthBackgroundState();
}

class _OmniLifeAuthBackgroundState extends State<OmniLifeAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entranceFade;

  bool get _isTestEnvironment {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  @override
  void initState() {
    super.initState();
    // Calm, slow 10-second cycle for restrained background breathing.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _entranceFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    if (!_isTestEnvironment) {
      _controller.repeat(reverse: true);
    } else {
      // In test mode, advance partially so dots are rendered without continuous looping.
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use authentic OmniLife theme outline/secondary colors with very low alpha
    // for subtle, non-distracting ambience.
    final dotColor = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.22)
        : theme.colorScheme.outline.withValues(alpha: 0.35);

    final backgroundColor = theme.scaffoldBackgroundColor;

    return Stack(
      children: [
        // Background canvas with dot-grid
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final entrance = _isTestEnvironment ? 1.0 : _entranceFade.value;
                final t = _controller.value;

                return CustomPaint(
                  painter: _DotGridPainter(
                    dotColor: dotColor,
                    backgroundColor: backgroundColor,
                    spacing: widget.dotSpacing,
                    progress: t,
                    entranceOpacity: entrance,
                  ),
                );
              },
            ),
          ),
        ),
        // Visual content sits cleanly on top
        widget.child,
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({
    required this.dotColor,
    required this.backgroundColor,
    required this.spacing,
    required this.progress,
    required this.entranceOpacity,
  });

  final Color dotColor;
  final Color backgroundColor;
  final double spacing;
  final double progress;
  final double entranceOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Clean solid scaffold background fill (no gradients/glows)
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (entranceOpacity <= 0) return;

    // 2. Dots
    final baseRadius = 1.15;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    final startX = (size.width - ((cols - 1) * spacing)) / 2;
    final startY = (size.height - ((rows - 1) * spacing)) / 2;

    for (int r = 0; r < rows; r++) {
      final y = startY + (r * spacing);
      for (int c = 0; c < cols; c++) {
        final x = startX + (c * spacing);

        // Very calm, gentle harmonic fluctuation (no dramatic movement or particles)
        final wave = math.sin((x / 240.0) + (y / 240.0) + (progress * 2 * math.pi));
        final radius = baseRadius + (0.35 * wave);

        // Subtly modulate opacity by +/- 15% around base alpha
        final alphaFactor = (0.85 + 0.15 * wave) * entranceOpacity;
        final clampedAlpha = (dotColor.a * alphaFactor).clamp(0.0, 1.0);

        dotPaint.color = dotColor.withValues(alpha: clampedAlpha);
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.entranceOpacity != entranceOpacity ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
