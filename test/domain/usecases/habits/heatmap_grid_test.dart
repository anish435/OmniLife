import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/usecases/habits/heatmap_grid.dart';

void main() {
  // Wednesday 11 March 2026.
  final today = DateTime(2026, 3, 11, 20);

  test('covers exactly 365 days ending today, 7 rows per column', () {
    final grid = HeatmapGrid.build(completedDates: {}, today: today);
    final cells = grid.weeks.expand((w) => w).whereType<HeatmapCell>().toList();
    expect(cells.length, 365);
    expect(grid.totalDays, 365);
    expect(grid.weeks.every((w) => w.length == 7), isTrue);
    expect(cells.last.date, DateTime(2026, 3, 11));
    expect(cells.last.isToday, isTrue);
    expect(cells.where((c) => c.isToday).length, 1);
    // 12 Mar 2025 is the first visible day.
    expect(cells.first.date, DateTime(2025, 3, 12));
    expect(grid.weeks.length, inInclusiveRange(52, 54));
  });

  test('columns are Monday-first weeks and padded outside the window', () {
    final grid = HeatmapGrid.build(completedDates: {}, today: today);
    // First visible day 12 Mar 2025 is a Wednesday, so Mon/Tue are blank.
    expect(grid.weeks.first[0], isNull);
    expect(grid.weeks.first[1], isNull);
    expect(grid.weeks.first[2]!.date, DateTime(2025, 3, 12));
    // Last column: today is Wednesday (row 2); Thu-Sun are blank.
    final last = grid.weeks.last;
    expect(last[2]!.date, DateTime(2026, 3, 11));
    expect(last.skip(3).every((c) => c == null), isTrue);
  });

  test('done flags and summary count only logs inside the window', () {
    final grid = HeatmapGrid.build(
      completedDates: {
        '2026-03-11',
        '2026-03-10',
        '2025-03-12', // first day of window, inclusive
        '2025-03-11', // one day too old
        '2026-03-12', // future
        'bad',
      },
      today: today,
    );
    expect(grid.doneDays, 3);
    final done = grid.weeks
        .expand((w) => w)
        .whereType<HeatmapCell>()
        .where((c) => c.done)
        .map((c) => c.key)
        .toSet();
    expect(done, {'2026-03-11', '2026-03-10', '2025-03-12'});
  });

  test('month labels name each month once, in order, without crowding', () {
    final grid = HeatmapGrid.build(completedDates: {}, today: today);
    final names = grid.monthLabels.map((l) => l.label).toList();
    expect(names.first, 'Mar');
    expect(names, contains('Dec'));
    expect(names, contains('Jan'));
    for (var i = 1; i < grid.monthLabels.length; i++) {
      expect(
        grid.monthLabels[i].weekIndex - grid.monthLabels[i - 1].weekIndex,
        greaterThanOrEqualTo(3),
      );
    }
    // Labels fall on columns that contain the first of that month.
    final dec = grid.monthLabels.firstWhere((l) => l.label == 'Dec');
    expect(
      grid.weeks[dec.weekIndex].any(
        (c) => c != null && c.date.month == 12 && c.date.day == 1,
      ),
      isTrue,
    );
  });

  test('works on a leap-year window and across DST', () {
    final grid = HeatmapGrid.build(
      completedDates: {'2024-02-29'},
      today: DateTime(2024, 3, 31, 0, 30),
    );
    final cells = grid.weeks.expand((w) => w).whereType<HeatmapCell>().toList();
    expect(cells.length, 365);
    expect(cells.map((c) => c.key).toSet().length, 365);
    expect(cells.where((c) => c.done).single.key, '2024-02-29');
  });
}
