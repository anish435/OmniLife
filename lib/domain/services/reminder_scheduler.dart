import '../entities/reminder.dart';

/// Stable positive 31-bit notification id derived from a reminder id, so a
/// reminder can be rescheduled or cancelled without storing the id anywhere.
int reminderNotificationId(String reminderId) {
  var hash = 0x811c9dc5; // FNV-1a
  for (final unit in reminderId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// Turns saved reminders into alerts. Implementations must not throw:
/// a failed alarm should never lose the saved reminder.
abstract class ReminderScheduler {
  /// Schedules (or reschedules) [reminder]; cancels it when it is disabled
  /// or a one-off that has already passed.
  Future<void> schedule(Reminder reminder);

  Future<void> cancel(String reminderId);
}
