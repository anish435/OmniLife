import 'habit_streaks.dart';

class HeatmapCell {
  const HeatmapCell({
    required this.date,
    required this.key,
    required this.done,
    required this.isToday,
  });

  final DateTime date;
  final String key;
  final bool done;
  final bool isToday;
}

class HeatmapMonthLabel {
  const HeatmapMonthLabel(this.weekIndex, this.label);
  final int weekIndex;
  final String label;
}

/// A GitHub-style grid: one column per week (Monday first), seven rows.
/// Cells outside the visible window (before the first day or after today)
/// are `null` so the grid stays rectangular.
class HeatmapGrid {
  const HeatmapGrid({
    required this.weeks,
    required this.monthLabels,
    required this.doneDays,
    required this.totalDays,
  });

  /// `weeks[column][row]`, row 0 = Monday.
  final List<List<HeatmapCell?>> weeks;
  final List<HeatmapMonthLabel> monthLabels;
  final int doneDays;
  final int totalDays;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _minLabelGap = 3;

  static HeatmapGrid build({
    required Set<String> completedDates,
    required DateTime today,
    int days = 365,
  }) {
    final todayNo = HabitStreaks.dayNumberOfDate(today);
    final startNo = todayNo - (days - 1);
    final doneNos = <int>{};
    for (final k in completedDates) {
      final n = HabitStreaks.dayNumberOf(k);
      if (n != null && n >= startNo && n <= todayNo) doneNos.add(n);
    }

    // Monday on or before the first visible day.
    final firstColumnStart = startNo - (HabitStreaks.weekdayOf(startNo) - 1);
    final columns = ((todayNo - firstColumnStart) / 7).floor() + 1;

    final weeks = <List<HeatmapCell?>>[];
    for (var c = 0; c < columns; c++) {
      final column = <HeatmapCell?>[];
      for (var r = 0; r < 7; r++) {
        final n = firstColumnStart + c * 7 + r;
        if (n < startNo || n > todayNo) {
          column.add(null);
        } else {
          final date = HabitStreaks.dateOfDayNumber(n);
          column.add(
            HeatmapCell(
              date: date,
              key: HabitStreaks.dateKey(date),
              done: doneNos.contains(n),
              isToday: n == todayNo,
            ),
          );
        }
      }
      weeks.add(column);
    }

    final labels = <HeatmapMonthLabel>[];
    int? lastMonth;
    var lastLabelColumn = -_minLabelGap;
    for (var c = 0; c < weeks.length; c++) {
      final firstCell = weeks[c].firstWhere(
        (e) => e != null,
        orElse: () => null,
      );
      if (firstCell == null) continue;
      // Label the column that contains the 1st of a month (or the first
      // column, so the leftmost month is always named).
      final containsFirst = weeks[c].any((e) => e != null && e.date.day == 1);
      final month = containsFirst
          ? weeks[c].firstWhere((e) => e != null && e.date.day == 1)!.date.month
          : firstCell.date.month;
      if (c == 0 || (containsFirst && month != lastMonth)) {
        if (c - lastLabelColumn >= _minLabelGap) {
          labels.add(HeatmapMonthLabel(c, _months[month - 1]));
          lastLabelColumn = c;
        }
        lastMonth = month;
      }
    }

    return HeatmapGrid(
      weeks: weeks,
      monthLabels: labels,
      doneDays: doneNos.length,
      totalDays: days,
    );
  }
}
