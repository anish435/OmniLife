import 'package:flutter/material.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/usecases/habits/heatmap_grid.dart';

/// 365-day consistency heatmap: one column per week (Monday first), seven
/// rows, month labels on top, a legend, and a plain-language summary.
/// Scrolls horizontally on narrow screens and starts at the latest week.
class HabitHeatmap extends StatefulWidget {
  const HabitHeatmap({
    super.key,
    required this.completedDates,
    required this.today,
    required this.longestStreak,
    this.streakUnit = 'day',
    this.color,
  });

  /// `yyyy-MM-dd` keys of completed days (from habit_logs).
  final Set<String> completedDates;
  final DateTime today;
  final int longestStreak;

  /// `day` or `week`, used in the summary line.
  final String streakUnit;
  final Color? color;

  static const cellSize = 12.0;
  static const cellGap = 3.0;
  static const _weekdayLabels = ['Mon', '', 'Wed', '', 'Fri', '', ''];
  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// e.g. "Wednesday 11 March 2026".
  static String describeDate(DateTime d) =>
      '${_weekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  static String summaryText(
    int doneDays,
    int totalDays,
    int longest,
    String unit,
  ) {
    final u = longest == 1 ? unit : '${unit}s';
    return '$doneDays of $totalDays days, longest streak $longest $u';
  }

  @override
  State<HabitHeatmap> createState() => _HabitHeatmapState();
}

class _HabitHeatmapState extends State<HabitHeatmap> {
  final _scroll = ScrollController();
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    // Start at the right edge: the most recent week is the one that matters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final doneColor = widget.color ?? semantic.habits;
    final grid = HeatmapGrid.build(
      completedDates: widget.completedDates,
      today: widget.today,
    );
    const step = HabitHeatmap.cellSize + HabitHeatmap.cellGap;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: semantic.tertiaryText,
    );

    HeatmapCell? selected;
    if (_selectedKey != null) {
      for (final w in grid.weeks) {
        for (final c in w) {
          if (c != null && c.key == _selectedKey) selected = c;
        }
      }
    }

    final labelsByColumn = {
      for (final l in grid.monthLabels) l.weekIndex: l.label,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          HabitHeatmap.summaryText(
            grid.doneDays,
            grid.totalDays,
            widget.longestStreak,
            widget.streakUnit,
          ),
          key: const ValueKey('heatmap-summary'),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.smPlus),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed weekday labels so they stay visible while scrolling.
            Padding(
              padding: const EdgeInsets.only(top: step),
              child: Column(
                children: [
                  for (final l in HabitHeatmap._weekdayLabels)
                    SizedBox(
                      height: step,
                      width: 28,
                      child: Text(l, style: labelStyle),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('heatmap-scroll'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: step,
                      width: grid.weeks.length * step,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final e in labelsByColumn.entries)
                            Positioned(
                              left: e.key * step,
                              top: 0,
                              child: Text(
                                e.value,
                                style: labelStyle,
                                softWrap: false,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        for (final week in grid.weeks)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: HabitHeatmap.cellGap,
                            ),
                            child: Column(
                              children: [
                                for (final cell in week)
                                  _CellView(
                                    cell: cell,
                                    doneColor: doneColor,
                                    selected:
                                        cell != null &&
                                        cell.key == _selectedKey,
                                    onTap: cell == null
                                        ? null
                                        : () => setState(
                                            () => _selectedKey = cell.key,
                                          ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          selected == null
              ? 'Tap a day to see its status'
              : '${HabitHeatmap.describeDate(selected.date)}: '
                    '${selected.done ? 'Done' : 'Not done'}',
          key: const ValueKey('heatmap-selected'),
          style: theme.textTheme.bodySmall?.copyWith(color: semantic.mutedText),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Legend(doneColor: doneColor),
      ],
    );
  }
}

class _CellView extends StatelessWidget {
  const _CellView({
    required this.cell,
    required this.doneColor,
    required this.selected,
    required this.onTap,
  });

  final HeatmapCell? cell;
  final Color doneColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = HabitHeatmap.cellSize;
    const gap = HabitHeatmap.cellGap;
    final c = cell;
    if (c == null) {
      return const SizedBox(width: size, height: size + gap);
    }
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final borderColor = selected
        ? theme.colorScheme.onSurface
        : (c.isToday ? theme.colorScheme.primary : semantic.hairline);
    return Semantics(
      button: true,
      label:
          '${HabitHeatmap.describeDate(c.date)}, ${c.done ? 'done' : 'not done'}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: Container(
              key: ValueKey('heat-${c.key}'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: c.done ? doneColor : semantic.surfaceRaised,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: c.done && !selected && !c.isToday
                      ? doneColor
                      : borderColor,
                  width: selected || c.isToday ? 1.5 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.doneColor});

  final Color doneColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: semantic.mutedText,
    );

    Widget swatch(Color fill, Color border, {double width = 1}) => Container(
      width: HabitHeatmap.cellSize,
      height: HabitHeatmap.cellSize,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border, width: width),
      ),
    );

    return Semantics(
      container: true,
      label:
          'Legend: filled square is a completed day, empty square is a '
          'day not completed, outlined square is today',
      child: ExcludeSemantics(
        child: Wrap(
          key: const ValueKey('heatmap-legend'),
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                swatch(semantic.surfaceRaised, semantic.hairline),
                const SizedBox(width: AppSpacing.xs),
                Text('Not done', style: style),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                swatch(doneColor, doneColor),
                const SizedBox(width: AppSpacing.xs),
                Text('Done', style: style),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                swatch(
                  semantic.surfaceRaised,
                  theme.colorScheme.primary,
                  width: 1.5,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('Today', style: style),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
