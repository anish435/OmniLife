import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/calendar_event.dart';

void main() {
  group('CalendarEvent', () {
    final start = DateTime(2026, 10, 3, 10, 0);
    final end = DateTime(2026, 10, 3, 11, 30);
    final created = DateTime(2026, 10, 3, 9, 0);

    test('calculates duration correctly', () {
      final event = CalendarEvent(
        id: 'e1',
        userId: 'u1',
        title: 'Standup',
        startAt: start,
        endAt: end,
        createdAt: created,
        updatedAt: created,
      );

      expect(event.duration, const Duration(minutes: 90));
      expect(event.isAllDay, isFalse);
      expect(event.type, CalendarEventType.event);
    });

    test('copyWith updates specified fields only', () {
      final event = CalendarEvent(
        id: 'e1',
        userId: 'u1',
        title: 'Original Title',
        startAt: start,
        endAt: end,
        colorTag: 'blue',
        createdAt: created,
        updatedAt: created,
      );

      final updated = event.copyWith(
        title: 'Updated Title',
        colorTag: 'emerald',
        type: CalendarEventType.focusBlock,
      );

      expect(updated.id, 'e1');
      expect(updated.title, 'Updated Title');
      expect(updated.colorTag, 'emerald');
      expect(updated.type, CalendarEventType.focusBlock);
      expect(updated.startAt, start);
    });

    test('value equality and hashCode match for identical properties', () {
      final e1 = CalendarEvent(
        id: 'e1',
        userId: 'u1',
        title: 'Design Review',
        startAt: start,
        endAt: end,
        colorTag: 'purple',
        createdAt: created,
        updatedAt: created,
      );

      final e2 = CalendarEvent(
        id: 'e1',
        userId: 'u1',
        title: 'Design Review',
        startAt: start,
        endAt: end,
        colorTag: 'purple',
        createdAt: created,
        updatedAt: created,
      );

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
    });
  });
}
