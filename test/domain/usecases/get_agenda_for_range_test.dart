import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/calendar_event.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/usecases/calendar/get_agenda_for_range.dart';

void main() {
  group('GetAgendaForRange', () {
    const useCase = GetAgendaForRange();

    final day = DateTime(2026, 10, 3);
    final dayStart = DateTime(2026, 10, 3, 0, 0);
    final dayEnd = DateTime(2026, 10, 3, 23, 59, 59);

    final event1 = CalendarEvent(
      id: 'e1',
      userId: 'u1',
      title: 'Morning Meeting',
      startAt: DateTime(2026, 10, 3, 9, 0),
      endAt: DateTime(2026, 10, 3, 10, 0),
      createdAt: DateTime(2026, 10, 3),
      updatedAt: DateTime(2026, 10, 3),
    );

    final event2 = CalendarEvent(
      id: 'e2',
      userId: 'u1',
      title: 'Overlapping Review',
      startAt: DateTime(2026, 10, 3, 9, 30),
      endAt: DateTime(2026, 10, 3, 10, 30),
      createdAt: DateTime(2026, 10, 3),
      updatedAt: DateTime(2026, 10, 3),
    );

    final allDayEvent = CalendarEvent(
      id: 'e_allday',
      userId: 'u1',
      title: 'Company Holiday',
      startAt: DateTime(2026, 10, 3, 0, 0),
      endAt: DateTime(2026, 10, 3, 23, 59),
      isAllDay: true,
      createdAt: DateTime(2026, 10, 3),
      updatedAt: DateTime(2026, 10, 3),
    );

    final taskWithDue = Task(
      id: 't1',
      userId: 'u1',
      title: 'Submit quarterly budget',
      completed: false,
      priority: TaskPriority.high,
      dueDate: DateTime(2026, 10, 3, 14, 0),
      createdAt: DateTime(2026, 10, 3),
      updatedAt: DateTime(2026, 10, 3),
    );

    final taskWithoutDue = Task(
      id: 't2',
      userId: 'u1',
      title: 'Backlog idea',
      completed: false,
      priority: TaskPriority.low,
      dueDate: null,
      createdAt: DateTime(2026, 10, 3),
      updatedAt: DateTime(2026, 10, 3),
    );

    test('merges events and tasks with due date in chronological order', () {
      final items = useCase.call(
        events: [event1, event2],
        tasks: [taskWithDue, taskWithoutDue],
        start: dayStart,
        end: dayEnd,
      );

      expect(items, hasLength(3));
      expect(items[0], isA<AgendaEventItem>());
      expect(items[0].title, 'Morning Meeting');
      expect(items[1], isA<AgendaEventItem>());
      expect(items[1].title, 'Overlapping Review');
      expect(items[2], isA<AgendaTaskItem>());
      expect(items[2].title, 'Submit quarterly budget');
    });

    test('packDayEvents computes side-by-side columns for overlapping events', () {
      final layouts = useCase.packDayEvents([event1, event2], day);

      expect(layouts, hasLength(2));
      expect(layouts[0].event.id, 'e1');
      expect(layouts[1].event.id, 'e2');

      // Since event1 and event2 overlap from 9:30 to 10:00, totalColumns must be 2
      expect(layouts[0].totalColumns, 2);
      expect(layouts[1].totalColumns, 2);
      expect(layouts[0].column, 0);
      expect(layouts[1].column, 1);
    });

    test('packDayEvents excludes all-day events from timed timeline', () {
      final layouts = useCase.packDayEvents([event1, allDayEvent], day);

      expect(layouts, hasLength(1));
      expect(layouts.first.event.id, 'e1');
      expect(layouts.first.totalColumns, 1);
      expect(layouts.first.column, 0);
    });

    test('packDayEvents handles non-overlapping sequential events cleanly', () {
      final eventA = CalendarEvent(
        id: 'ea',
        userId: 'u1',
        title: 'Morning',
        startAt: DateTime(2026, 10, 3, 9, 0),
        endAt: DateTime(2026, 10, 3, 10, 0),
        createdAt: DateTime(2026, 10, 3),
        updatedAt: DateTime(2026, 10, 3),
      );
      final eventB = CalendarEvent(
        id: 'eb',
        userId: 'u1',
        title: 'Afternoon',
        startAt: DateTime(2026, 10, 3, 14, 0),
        endAt: DateTime(2026, 10, 3, 15, 0),
        createdAt: DateTime(2026, 10, 3),
        updatedAt: DateTime(2026, 10, 3),
      );

      final layouts = useCase.packDayEvents([eventA, eventB], day);

      expect(layouts, hasLength(2));
      expect(layouts[0].totalColumns, 1);
      expect(layouts[0].column, 0);
      expect(layouts[1].totalColumns, 1);
      expect(layouts[1].column, 0);
    });
  });
}
