import 'package:intl/intl.dart';

import '../../domain/entities/reminder.dart';

/// Plain-words description of when a reminder fires, for lists and
/// notification bodies: "Today, 9:00 PM", "Every day at 8:00 AM",
/// "Every Monday at 8:00 AM".
String describeReminderWhen(Reminder r, DateTime now) {
  final time = DateFormat('h:mm a').format(r.scheduledAt);
  switch (r.repeat) {
    case ReminderRepeat.daily:
      return 'Every day at $time';
    case ReminderRepeat.weekly:
      return 'Every ${DateFormat('EEEE').format(r.scheduledAt)} at $time';
    case ReminderRepeat.none:
      return '${describeDay(r.scheduledAt, now)}, $time';
  }
}

/// "Today", "Tomorrow", "Yesterday", otherwise "Fri, Mar 6" (with the year
/// when it is not the current one).
String describeDay(DateTime date, DateTime now) {
  // UTC midnights so a daylight-saving change never skews the day count.
  final today = DateTime.utc(now.year, now.month, now.day);
  final day = DateTime.utc(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  final pattern = date.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y';
  return DateFormat(pattern).format(date);
}
