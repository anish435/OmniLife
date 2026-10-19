import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/data/models/reminder_model.dart';
import 'package:omnilife/domain/entities/reminder.dart';

Reminder make({
  required DateTime at,
  ReminderRepeat repeat = ReminderRepeat.none,
  bool enabled = true,
}) => Reminder(
  id: 'r1',
  userId: 'u1',
  title: 'Take medicine',
  scheduledAt: at,
  repeat: repeat,
  enabled: enabled,
  createdAt: DateTime(2026, 3, 1),
  updatedAt: DateTime(2026, 3, 1),
);

void main() {
  group('nextFire', () {
    final now = DateTime(2026, 3, 4, 12); // a Wednesday

    test('one-off in the future fires at its time', () {
      final r = make(at: DateTime(2026, 3, 4, 18));
      expect(r.nextFire(now), DateTime(2026, 3, 4, 18));
    });

    test('one-off in the past never fires again', () {
      expect(make(at: DateTime(2026, 3, 4, 8)).nextFire(now), isNull);
    });

    test('disabled reminders never fire', () {
      final r = make(
        at: DateTime(2026, 3, 5, 8),
        repeat: ReminderRepeat.daily,
        enabled: false,
      );
      expect(r.nextFire(now), isNull);
    });

    test('daily rolls to later today or tomorrow', () {
      final later = make(
        at: DateTime(2026, 1, 1, 18, 30),
        repeat: ReminderRepeat.daily,
      );
      expect(later.nextFire(now), DateTime(2026, 3, 4, 18, 30));
      final passed = make(
        at: DateTime(2026, 1, 1, 8),
        repeat: ReminderRepeat.daily,
      );
      expect(passed.nextFire(now), DateTime(2026, 3, 5, 8));
    });

    test('weekly lands on the same weekday', () {
      // 2026-01-05 was a Monday.
      final r = make(
        at: DateTime(2026, 1, 5, 9),
        repeat: ReminderRepeat.weekly,
      );
      final next = r.nextFire(now)!;
      expect(next, DateTime(2026, 3, 9, 9));
      expect(next.weekday, DateTime.monday);
    });
  });

  group('ReminderModel', () {
    final reminder = Reminder(
      id: 'r1',
      userId: 'u1',
      title: 'Water the plants',
      scheduledAt: DateTime(2026, 3, 4, 8, 15),
      repeat: ReminderRepeat.weekly,
      note: 'Balcony too',
      enabled: false,
      createdAt: DateTime(2026, 3, 1, 9),
      updatedAt: DateTime(2026, 3, 2, 9),
    );

    test('round trips through a SQLite row', () {
      final back = ReminderModel.fromMap(ReminderModel(reminder).toMap());
      expect(back.reminder, reminder);
    });

    test('round trips through a Firestore document', () {
      final map = ReminderModel(reminder).toFirestoreMap();
      expect(map['repeat'], 'weekly');
      expect(map['enabled'], false);
      final back = ReminderModel.fromFirestoreMap('r1', map);
      expect(back.reminder, reminder);
    });

    test('unknown repeat falls back to once', () {
      final back = ReminderModel.fromFirestoreMap('r1', {
        'userId': 'u1',
        'title': 'x',
        'scheduledAt': 1000,
        'repeat': 'monthly',
      });
      expect(back.reminder.repeat, ReminderRepeat.none);
      expect(back.reminder.enabled, isTrue);
    });
  });
}
