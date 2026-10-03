import 'package:flutter/material.dart';

/// Clean hourly time gutter for day and week timelines.
class TimeGutter extends StatelessWidget {
  const TimeGutter({
    super.key,
    required this.hourHeight,
    this.startHour = 0,
    this.endHour = 24,
  });

  final double hourHeight;
  final int startHour;
  final int endHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    return SizedBox(
      width: 48,
      child: Column(
        children: [
          for (int h = startHour; h < endHour; h++)
            SizedBox(
              height: hourHeight,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 0),
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal background hour grid lines matching TimeGutter height.
class HourGridLines extends StatelessWidget {
  const HourGridLines({
    super.key,
    required this.hourHeight,
    this.startHour = 0,
    this.endHour = 24,
  });

  final double hourHeight;
  final int startHour;
  final int endHour;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? const Color(0xFF33383F).withValues(alpha: 0.5)
        : const Color(0xFFDADFE3).withValues(alpha: 0.6);

    return Column(
      children: [
        for (int h = startHour; h < endHour; h++)
          Container(
            height: hourHeight,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: dividerColor, width: 0.5),
              ),
            ),
          ),
      ],
    );
  }
}
