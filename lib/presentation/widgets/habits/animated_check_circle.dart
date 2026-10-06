import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_semantic_colors.dart';

/// A circular day marker. When it flips to completed the check mark is drawn
/// stroke by stroke and the circle gives a short scale pulse. Both are skipped
/// (the final state is shown immediately) when the platform asks for reduced
/// motion via `MediaQuery.disableAnimations`.
///
/// Completing also fires a light haptic tick, unless [haptics] is false.
class AnimatedCheckCircle extends StatefulWidget {
  const AnimatedCheckCircle({
    super.key,
    required this.completed,
    required this.onTap,
    this.size = 32,
    this.fillColor,
    this.checkColor,
    this.highlightToday = false,
    this.semanticLabel,
    this.haptics = true,
  });

  final bool completed;
  final VoidCallback? onTap;
  final double size;
  final Color? fillColor;
  final Color? checkColor;

  /// Draws an accent ring while not completed (used for today).
  final bool highlightToday;
  final String? semanticLabel;
  final bool haptics;

  @override
  State<AnimatedCheckCircle> createState() => _AnimatedCheckCircleState();
}

class _AnimatedCheckCircleState extends State<AnimatedCheckCircle>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 320);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.completed ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant AnimatedCheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completed == widget.completed) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.completed) {
      _controller.value = 0;
    } else if (reduce) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    if (widget.haptics && !widget.completed) {
      HapticFeedback.lightImpact();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final fill = widget.fillColor ?? theme.colorScheme.primary;
    final check = widget.checkColor ?? theme.colorScheme.onPrimary;
    final size = widget.size;

    return Semantics(
      button: true,
      checked: widget.completed,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: SizedBox(
            // 48dp minimum touch target around the visible circle.
            width: size < 48 ? 48 : size,
            height: size < 48 ? 48 : size,
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  // Pulse 1 -> 1.15 -> 1 over the first 60% of the run.
                  final pulse = t >= 0.6
                      ? 1.0
                      : 1 + 0.15 * (1 - ((t / 0.3) - 1).abs());
                  return Transform.scale(
                    scale: _controller.isAnimating ? pulse : 1,
                    child: Container(
                      key: const ValueKey('check-circle'),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.completed
                            ? fill
                            : theme.colorScheme.surfaceContainerHighest,
                        border: !widget.completed && widget.highlightToday
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 1.5,
                              )
                            : Border.all(color: semantic.hairline),
                      ),
                      child: widget.completed
                          ? CustomPaint(
                              painter: _CheckPainter(
                                progress: Curves.easeOut.transform(
                                  ((t - 0.1) / 0.9).clamp(0.0, 1.0),
                                ),
                                color: check,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.27, h * 0.52)
      ..lineTo(w * 0.43, h * 0.67)
      ..lineTo(w * 0.73, h * 0.36);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.09).clamp(1.5, 3.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
}
