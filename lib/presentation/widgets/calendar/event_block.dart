import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/calendar_event.dart';
import 'calendar_colors.dart';

/// Clean event block component for timeline and agenda views.
///
/// Features:
/// - Solid 3px left edge bar
/// - Tinted background at ~14% opacity
/// - Text in the full tone
/// - Truncates gracefully based on available height:
///   - height < 32: title only inline
///   - height >= 32: title + time with tabular figures
class EventBlock extends StatefulWidget {
  const EventBlock({
    super.key,
    required this.event,
    this.height,
    this.onTap,
  });

  final CalendarEvent event;
  final double? height;
  final VoidCallback? onTap;

  @override
  State<EventBlock> createState() => _EventBlockState();
}

class _EventBlockState extends State<EventBlock> {
  bool _isPressed = false;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tag = CalendarColors.getTag(widget.event.colorTag);

    final h = widget.height ?? 54.0;
    final isCompact = h < 34.0;

    final timeLabel = widget.event.isAllDay
        ? 'All Day'
        : '${_formatTime(widget.event.startAt)} - ${_formatTime(widget.event.endAt)}';

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: tag.background(isDark),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tag.border(isDark),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3px solid edge bar
              Container(
                width: 3.5,
                color: tag.color,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: isCompact ? 2 : 4,
                  ),
                  child: isCompact
                      ? Row(
                          children: [
                            if (widget.event.type == CalendarEventType.focusBlock)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.bolt_outlined,
                                  size: 11,
                                  color: tag.color,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                widget.event.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tag.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: tag.color.withValues(alpha: 0.8),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                if (widget.event.type == CalendarEventType.focusBlock)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.bolt_outlined,
                                      size: 12,
                                      color: tag.color,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    widget.event.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tag.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: tag.color.withValues(alpha: 0.8),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
