import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../pages/auth/auth_theme_tokens.dart';

/// Full-screen ambient animated background for OmniLife authentication.
///
/// Features:
/// 1. Subtle, performant animated dot-grid canvas painter using Indigo/Teal/AI tones.
/// 2. Soft, multi-stop radial glows/vignettes centered behind the auth card.
/// 3. Respects reduced-motion accessibility settings and test runners.
/// 4. Proper lifecycle and memory management with [SingleTickerProviderStateMixin].
class OmniLifeAuthBackground extends StatefulWidget {
  const OmniLifeAuthBackground({
    super.key,
    required this.child,
    this.enableAnimation = true,
  });

  final Widget child;
  final bool enableAnimation;

  @override
  State<OmniLifeAuthBackground> createState() => _OmniLifeAuthBackgroundState();
}

class _OmniLifeAuthBackgroundState extends State<OmniLifeAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _shouldAnimate(BuildContext context) {
    if (!widget.enableAnimation) return false;
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('Test') || Get.testMode) return false;
    return !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (widget.enableAnimation && !binding.contains('Test') && !Get.testMode) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shouldAnimate(context)) {
      if (_controller.isAnimating) _controller.stop();
    } else {
      if (!_controller.isAnimating) _controller.repeat();
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

    final bgColor = AuthThemeTokens.background(isDark);
    final primaryColor = AuthThemeTokens.primary(isDark);
    final tealColor = AuthThemeTokens.teal(isDark);
    final aiColor = AuthThemeTokens.ai(isDark);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient gradient base
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bgColor,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0F172A),
                          const Color(0xFF131D38),
                          const Color(0xFF0F172A),
                        ]
                      : [
                          const Color(0xFFF8F9FC),
                          const Color(0xFFEEF2FF),
                          const Color(0xFFF0FDFA),
                        ],
                ),
              ),
            ),
          ),

          // 2. Dual soft radial glows behind card
          Positioned.fill(
            child: CustomPaint(
              painter: _RadialGlowPainter(
                primaryColor: primaryColor,
                tealColor: tealColor,
                aiColor: aiColor,
                isDark: isDark,
              ),
            ),
          ),

          // 3. Native particle / dot-grid animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _DotGridPainter(
                    animationProgress: _controller.value,
                    primaryColor: primaryColor,
                    tealColor: tealColor,
                    aiColor: aiColor,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 4. Subtle perimeter vignette
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                          : const Color(0xFFF8F9FC).withValues(alpha: 0.5),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 5. Auth Card & Content
          widget.child,
        ],
      ),
    );
  }
}

/// Paints the multi-stop soft ambient halos centered in the viewport.
class _RadialGlowPainter extends CustomPainter {
  const _RadialGlowPainter({
    required this.primaryColor,
    required this.tealColor,
    required this.aiColor,
    required this.isDark,
  });

  final Color primaryColor;
  final Color tealColor;
  final Color aiColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Primary central glow
    final primaryRadius = math.min(size.width, size.height) * 0.65;
    final primaryPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: isDark ? 0.22 : 0.16),
          primaryColor.withValues(alpha: isDark ? 0.08 : 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: primaryRadius));
    canvas.drawCircle(center, primaryRadius, primaryPaint);

    // Subtle offset Teal accent glow
    final tealCenter = Offset(
      center.dx + size.width * 0.18,
      center.dy - size.height * 0.15,
    );
    final tealRadius = math.min(size.width, size.height) * 0.45;
    final tealPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          tealColor.withValues(alpha: isDark ? 0.14 : 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: tealCenter, radius: tealRadius));
    canvas.drawCircle(tealCenter, tealRadius, tealPaint);

    // Subtle offset Violet/AI accent glow
    final aiCenter = Offset(
      center.dx - size.width * 0.18,
      center.dy + size.height * 0.16,
    );
    final aiRadius = math.min(size.width, size.height) * 0.45;
    final aiPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          aiColor.withValues(alpha: isDark ? 0.14 : 0.09),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: aiCenter, radius: aiRadius));
    canvas.drawCircle(aiCenter, aiRadius, aiPaint);
  }

  @override
  bool shouldRepaint(covariant _RadialGlowPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.tealColor != tealColor;
}

/// Native performant CustomPainter that renders a geometric pulsing dot-grid
/// with subtle wave dynamics and coordinated Indigo, Teal, and Violet tones.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({
    required this.animationProgress,
    required this.primaryColor,
    required this.tealColor,
    required this.aiColor,
    required this.isDark,
  });

  final double animationProgress;
  final Color primaryColor;
  final Color tealColor;
  final Color aiColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 32.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxDist = math.sqrt(centerX * centerX + centerY * centerY);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final twoPi = 2 * math.pi;
    final timePhase = animationProgress * twoPi;

    for (int r = 0; r < rows; r++) {
      final y = r * spacing;
      for (int c = 0; c < cols; c++) {
        final x = c * spacing;

        final dx = x - centerX;
        final dy = y - centerY;
        final dist = math.sqrt(dx * dx + dy * dy);
        final normDist = dist / maxDist;

        // Wave formula combining radial distance and continuous time phase
        final wave = math.sin(timePhase + (x / 140.0) + (y / 180.0) - (normDist * 3.0));
        final waveVal = (wave + 1.0) / 2.0; // 0.0 .. 1.0

        // Determine subtle radius and opacity
        final isAccent = (r * 7 + c * 13) % 9 == 0;
        final isSubAccent = (r * 11 + c * 5) % 11 == 0;

        double radius;
        double opacity;
        Color dotColor;

        if (isAccent) {
          // Subtle glowing accent dot (Indigo / Teal)
          radius = 1.6 + (waveVal * 1.4);
          opacity = isDark ? (0.25 + waveVal * 0.45) : (0.18 + waveVal * 0.35);
          dotColor = Color.lerp(primaryColor, tealColor, waveVal)!;
        } else if (isSubAccent) {
          // Violet/AI secondary dot
          radius = 1.3 + (waveVal * 1.1);
          opacity = isDark ? (0.18 + waveVal * 0.35) : (0.14 + waveVal * 0.28);
          dotColor = Color.lerp(aiColor, primaryColor, waveVal)!;
        } else {
          // Standard background grid dot
          radius = 1.0 + (waveVal * 0.5);
          opacity = isDark ? (0.06 + waveVal * 0.12) : (0.05 + waveVal * 0.09);
          dotColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        }

        dotPaint.color = dotColor.withValues(alpha: opacity.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.isDark != isDark;
}
