import 'package:flutter/material.dart';

/// A plain pulsing dot with a soft ring, in the theme accent. Shown only
/// while the microphone is open.
class ListeningDot extends StatefulWidget {
  const ListeningDot({super.key, this.size = 14});

  final double size;

  @override
  State<ListeningDot> createState() => _ListeningDotState();
}

class _ListeningDotState extends State<ListeningDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final box = widget.size * 2;
    return Semantics(
      label: 'Listening',
      child: SizedBox(
        width: box,
        height: box,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            final ring = widget.size * (1 + 0.9 * t);
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: ring,
                  height: ring,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.22 * (1 - t) + 0.06),
                  ),
                ),
                Container(
                  width: widget.size * 0.7,
                  height: widget.size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
