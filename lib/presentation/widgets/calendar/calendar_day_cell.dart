import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/calendar_event.dart';
import 'calendar_colors.dart';

/// Clean calendar day cell for Month view with craft details:
/// - Tabular figures for dates
/// - Filled accent circle for Today
/// - Accent outline ring for Selected day
/// - 35% opacity for days outside the focused month
/// - Up to 3 event dot/bars with overflow indicator (+N)
class CalendarDayCell extends StatefulWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  @override
  State<CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<CalendarDayCell> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final isWeekend = widget.date.weekday == DateTime.saturday ||
        widget.date.weekday == DateTime.sunday;

    final baseOpacity = widget.isCurrentMonth ? 1.0 : 0.35;
    final surfaceTint = isWeekend
        ? (isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.015))
        : Colors.transparent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: baseOpacity,
          duration: const Duration(milliseconds: 150),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: surfaceTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDateNumber(primary, isDark),
                const SizedBox(height: 3),
                _buildEventIndicators(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNumber(Color primary, bool isDark) {
    final theme = Theme.of(context);
    final textColor = widget.isToday
        ? Colors.white
        : theme.colorScheme.onSurface;

    BoxDecoration? decoration;
    if (widget.isToday) {
      decoration = BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
      );
    } else if (widget.isSelected) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: primary, width: 1.5),
      );
    }

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: decoration,
      child: Text(
        '${widget.date.day}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: widget.isToday || widget.isSelected
              ? FontWeight.w600
              : FontWeight.normal,
          color: textColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildEventIndicators(bool isDark) {
    if (widget.events.isEmpty) {
      return const SizedBox(height: 6);
    }

    final maxDots = 3;
    final displayEvents = widget.events.take(maxDots).toList();
    final overflowCount = widget.events.length - maxDots;

    return SizedBox(
      height: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final event in displayEvents)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: CalendarColors.getTag(event.colorTag).color,
                shape: BoxShape.circle,
              ),
            ),
          if (overflowCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Text(
                '+$overflowCount',
                style: const TextStyle(
                  fontSize: 7,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
