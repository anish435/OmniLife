import '../entities/reminder.dart';

abstract class ReminderRepository {
  Future<List<Reminder>> list(String userId);
  Future<Reminder> create(Reminder reminder);
  Future<Reminder> update(Reminder reminder);
  Future<void> delete(Reminder reminder);
}

/// Persists a reminder AND schedules its local notification. The assistant
/// and the Reminders screen both go through this one entry point.
abstract class ReminderService {
  Future<Reminder> create({
    required String title,
    required DateTime at,
    ReminderRepeat repeat = ReminderRepeat.none,
    String? note,
  });
  Future<Reminder> update(Reminder reminder);
  Future<void> remove(Reminder reminder);
  Future<List<Reminder>> all();
}
