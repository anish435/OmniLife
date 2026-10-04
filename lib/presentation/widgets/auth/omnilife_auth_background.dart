import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../pages/auth/auth_theme_tokens.dart';

/// Full-screen ambient background for OmniLife authentication.
///
/// Strips out artificial violet/indigo neon glows and uses a warm,
/// restrained terracotta ambiance on warm paper / carbon slate.
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

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Solid ambient background
          Positioned.fill(
            child: ColoredBox(color: bgColor),
          ),

          // 2. Subtle, low-contrast warm radial glow behind card
          Positioned.fill(
            child: CustomPaint(
              painter: _WarmRadialGlowPainter(
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            ),
          ),

          // 3. Low-contrast restrained dot grid
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _EditorialDotGridPainter(
                    animationProgress: _controller.value,
                    primaryColor: primaryColor,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 4. Content
          widget.child,
        ],
      ),
    );
  }
}

class _WarmRadialGlowPainter extends CustomPainter {
  const _WarmRadialGlowPainter({
    required this.primaryColor,
    required this.isDark,
  });

  final Color primaryColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.55;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: isDark ? 0.08 : 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _WarmRadialGlowPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.primaryColor != primaryColor;
}

class _EditorialDotGridPainter extends CustomPainter {
  const _EditorialDotGridPainter({
    required this.animationProgress,
    required this.primaryColor,
    required this.isDark,
  });

  final double animationProgress;
  final Color primaryColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 36.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final twoPi = 2 * math.pi;
    final timePhase = animationProgress * twoPi;

    final baseDotColor = isDark
        ? AppColors.darkHairline.withValues(alpha: 0.6)
        : AppColors.lightHairline.withValues(alpha: 0.8);

    for (int r = 0; r < rows; r++) {
      final y = r * spacing;
      for (int c = 0; c < cols; c++) {
        final x = c * spacing;

        final wave = math.sin(timePhase + (x / 180.0) + (y / 220.0));
        final waveVal = (wave + 1.0) / 2.0;

        final isAccent = (r * 7 + c * 13) % 15 == 0;

        double radius;
        Color color;

        if (isAccent) {
          radius = 1.4;
          color = primaryColor.withValues(
            alpha: isDark ? (0.15 + waveVal * 0.15) : (0.12 + waveVal * 0.12),
          );
        } else {
          radius = 1.0;
          color = baseDotColor;
        }

        dotPaint.color = color;
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditorialDotGridPainter oldDelegate) =>
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.isDark != isDark;
}
