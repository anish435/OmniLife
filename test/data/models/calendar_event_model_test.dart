import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/models/calendar_event_model.dart';
import 'package:omnilife/domain/entities/calendar_event.dart';

void main() {
  group('CalendarEventModel', () {
    final start = DateTime.utc(2026, 10, 3, 14, 0);
    final end = DateTime.utc(2026, 10, 3, 15, 0);
    final now = DateTime.utc(2026, 10, 3, 12, 0);

    final model = CalendarEventModel(
      id: 'e100',
      userId: 'user_42',
      title: 'Sprint Planning',
      description: 'Review Q4 deliverables',
      startAt: start,
      endAt: end,
      isAllDay: false,
      colorTag: 'amber',
      type: CalendarEventType.focusBlock,
      linkedTaskId: 't99',
      createdAt: now,
      updatedAt: now,
    );

    test('toMap encodes integers and strings correctly for SQLite', () {
      final map = model.toMap();

      expect(map['id'], 'e100');
      expect(map['user_id'], 'user_42');
      expect(map['title'], 'Sprint Planning');
      expect(map['description'], 'Review Q4 deliverables');
      expect(map['start_at'], start.millisecondsSinceEpoch);
      expect(map['end_at'], end.millisecondsSinceEpoch);
      expect(map['is_all_day'], 0);
      expect(map['color_tag'], 'amber');
      expect(map['type'], 'focusBlock');
      expect(map['linked_task_id'], 't99');
      expect(map['created_at'], now.millisecondsSinceEpoch);
      expect(map['updated_at'], now.millisecondsSinceEpoch);
    });

    test('fromMap accurately reconstructs the CalendarEventModel', () {
      final map = model.toMap();
      final restored = CalendarEventModel.fromMap(map);

      expect(restored.id, model.id);
      expect(restored.userId, model.userId);
      expect(restored.title, model.title);
      expect(restored.description, model.description);
      expect(restored.startAt.millisecondsSinceEpoch, model.startAt.millisecondsSinceEpoch);
      expect(restored.endAt.millisecondsSinceEpoch, model.endAt.millisecondsSinceEpoch);
      expect(restored.isAllDay, isFalse);
      expect(restored.colorTag, 'amber');
      expect(restored.type, CalendarEventType.focusBlock);
      expect(restored.linkedTaskId, 't99');
    });

    test('toFirestoreMap encodes ISO-8601 timestamps', () {
      final fMap = model.toFirestoreMap();

      expect(fMap['userId'], 'user_42');
      expect(fMap['title'], 'Sprint Planning');
      expect(fMap['startAt'], start.toIso8601String());
      expect(fMap['endAt'], end.toIso8601String());
      expect(fMap['type'], 'focusBlock');
    });

    test('fromEntity and fromMap with bool handles both bool and int formats', () {
      final map = {
        'id': 'e2',
        'user_id': 'u1',
        'title': 'All day conference',
        'start_at': start.millisecondsSinceEpoch,
        'end_at': end.millisecondsSinceEpoch,
        'is_all_day': true,
        'color_tag': 'emerald',
        'type': 'event',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      };

      final restored = CalendarEventModel.fromMap(map);
      expect(restored.isAllDay, isTrue);
      expect(restored.type, CalendarEventType.event);
    });
  });
}
