import '../../entities/calendar_event.dart';
import '../../entities/task.dart';

sealed class AgendaItem implements Comparable<AgendaItem> {
  const AgendaItem();

  String get id;
  String get title;
  DateTime get time;
  bool get isCompleted;

  @override
  int compareTo(AgendaItem other) {
    final cmp = time.compareTo(other.time);
    if (cmp != 0) return cmp;
    return title.compareTo(other.title);
  }
}

class AgendaEventItem extends AgendaItem {
  const AgendaEventItem(this.event);

  final CalendarEvent event;

  @override
  String get id => event.id;

  @override
  String get title => event.title;

  @override
  DateTime get time => event.startAt;

  @override
  bool get isCompleted => false;

  bool get isAllDay => event.isAllDay;
}

class AgendaTaskItem extends AgendaItem {
  const AgendaTaskItem(this.task);

  final Task task;

  @override
  String get id => task.id;

  @override
  String get title => task.title;

  @override
  DateTime get time => task.dueDate ?? task.createdAt;

  @override
  bool get isCompleted => task.completed;
}

/// Represents positioned placement data for rendering an event block in Day/Week views.
class PositionedEventLayout {
  const PositionedEventLayout({
    required this.event,
    required this.column,
    required this.totalColumns,
    required this.topMinutes,
    required this.durationMinutes,
  });

  final CalendarEvent event;
  final int column;
  final int totalColumns;
  final double topMinutes;
  final double durationMinutes;
}

/// Use case to merge CalendarEvents and Tasks with due dates for a given date range.
class GetAgendaForRange {
  const GetAgendaForRange();

  /// Merges events and tasks whose scheduled time falls on or overlaps [start] to [end].
  List<AgendaItem> call({
    required List<CalendarEvent> events,
    required List<Task> tasks,
    required DateTime start,
    required DateTime end,
  }) {
    final startMillis = start.millisecondsSinceEpoch;
    final endMillis = end.millisecondsSinceEpoch;

    final result = <AgendaItem>[];

    // Filter events overlapping [start, end)
    for (final event in events) {
      final eStart = event.startAt.millisecondsSinceEpoch;
      final eEnd = event.endAt.millisecondsSinceEpoch;
      if (eStart < endMillis && eEnd > startMillis) {
        result.add(AgendaEventItem(event));
      }
    }

    // Filter tasks with dueDate within [start, end)
    for (final task in tasks) {
      if (task.dueDate != null) {
        final dMillis = task.dueDate!.millisecondsSinceEpoch;
        if (dMillis >= startMillis && dMillis <= endMillis) {
          result.add(AgendaTaskItem(task));
        }
      }
    }

    result.sort();
    return result;
  }

  /// Calculates side-by-side packed column layouts for non-all-day events on [day].
  List<PositionedEventLayout> packDayEvents(
    List<CalendarEvent> events,
    DateTime day,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Exclude all-day events from the timed vertical column
    final dayEvents = events.where((e) {
      if (e.isAllDay) return false;
      return e.startAt.isBefore(dayEnd) && e.endAt.isAfter(dayStart);
    }).toList();

    if (dayEvents.isEmpty) return const [];

    // Sort by start time, then by longer duration first
    dayEvents.sort((a, b) {
      final cmp = a.startAt.compareTo(b.startAt);
      if (cmp != 0) return cmp;
      return b.duration.compareTo(a.duration);
    });

    final eventLayouts = <_EventWithTime>[];
    for (final e in dayEvents) {
      // Calculate top minute offset (0 to 1440)
      final effectiveStart = e.startAt.isBefore(dayStart) ? dayStart : e.startAt;
      final effectiveEnd = e.endAt.isAfter(dayEnd) ? dayEnd : e.endAt;

      final startMin = effectiveStart.hour * 60.0 + effectiveStart.minute;
      var endMin = effectiveEnd.hour * 60.0 + effectiveEnd.minute;
      if (effectiveEnd.isAtSameMomentAs(dayEnd)) {
        endMin = 1440.0;
      }
      final durationMin = (endMin - startMin).clamp(15.0, 1440.0);

      eventLayouts.add(_EventWithTime(
        event: e,
        startMin: startMin,
        endMin: endMin,
        durationMin: durationMin,
      ));
    }

    // Group overlapping events into clusters
    final clusters = <List<_EventWithTime>>[];
    List<_EventWithTime>? currentCluster;
    double clusterEnd = -1;

    for (final item in eventLayouts) {
      if (currentCluster == null || item.startMin >= clusterEnd) {
        currentCluster = [item];
        clusters.add(currentCluster);
        clusterEnd = item.endMin;
      } else {
        currentCluster.add(item);
        if (item.endMin > clusterEnd) {
          clusterEnd = item.endMin;
        }
      }
    }

    final result = <PositionedEventLayout>[];

    for (final cluster in clusters) {
      // Assign column indices
      final columns = <List<_EventWithTime>>[];

      for (final item in cluster) {
        int placedCol = -1;
        for (int c = 0; c < columns.length; c++) {
          final lastInCol = columns[c].last;
          if (item.startMin >= lastInCol.endMin) {
            columns[c].add(item);
            placedCol = c;
            break;
          }
        }
        if (placedCol == -1) {
          columns.add([item]);
          placedCol = columns.length - 1;
        }
        item.column = placedCol;
      }

      final totalCols = columns.length;
      for (final item in cluster) {
        result.add(PositionedEventLayout(
          event: item.event,
          column: item.column,
          totalColumns: totalCols,
          topMinutes: item.startMin,
          durationMinutes: item.durationMin,
        ));
      }
    }

    return result;
  }
}

class _EventWithTime {
  _EventWithTime({
    required this.event,
    required this.startMin,
    required this.endMin,
    required this.durationMin,
  });

  final CalendarEvent event;
  final double startMin;
  final double endMin;
  final double durationMin;
  int column = 0;
}
