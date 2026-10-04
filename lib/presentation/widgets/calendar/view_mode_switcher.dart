import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/calendar_controller.dart';

/// Compact segmented control switching between Month, Week, and Day views.
class ViewModeSwitcher extends StatelessWidget {
  const ViewModeSwitcher({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  final CalendarViewMode selectedMode;
  final ValueChanged<CalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final surfaceColor = theme.colorScheme.surface;

    return Container(
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(context, CalendarViewMode.month, 'Month'),
          _buildSegment(context, CalendarViewMode.week, 'Week'),
          _buildSegment(context, CalendarViewMode.day, 'Day'),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    CalendarViewMode mode,
    String label,
  ) {
    final theme = Theme.of(context);
    final isSelected = selectedMode == mode;
    final primaryColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          HapticFeedback.lightImpact();
          onChanged(mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? primaryColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
