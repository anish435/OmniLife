import '../entities/reminder.dart';
import 'tool_args.dart';

class ResolvedReminder {
  const ResolvedReminder(this.at, this.repeat);

  final DateTime at;
  final ReminderRepeat repeat;
}

/// Turns what the model extracted plus the user's own words into a firm
/// reminder time and repeat rule.
///
/// The model is good at reading dates but inconsistent about house rules,
/// so the rules the app promises live here, in plain code, and are tested:
///  - tonight 9 PM, morning 8 AM, afternoon 2 PM, evening 6 PM
///  - daily / every day / each day / everyday / every morning / night
///    means daily; weekly / every `<weekday>` means weekly; otherwise once
///  - a one-off whose time already passed today moves to tomorrow
class ReminderTimeResolver {
  const ReminderTimeResolver(this.now);

  final DateTime now;

  static final _weekday = RegExp(
    r'\bevery\s+(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)[a-z]*\b',
  );
  static final _daily = RegExp(
    r'\b(daily|everyday|every\s+day|each\s+day|(every|each)\s+(morning|night|evening|afternoon))\b',
  );
  static final _weekly = RegExp(r'\b(weekly|every\s+week|each\s+week)\b');

  static ReminderRepeat detectRepeat(String text) {
    final t = text.toLowerCase();
    if (_weekday.hasMatch(t)) return ReminderRepeat.weekly;
    if (_daily.hasMatch(t)) return ReminderRepeat.daily;
    if (_weekly.hasMatch(t)) return ReminderRepeat.weekly;
    return ReminderRepeat.none;
  }

  /// Default hour for a day-part word, or null.
  static int? dayPartHour(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'\btonight\b').hasMatch(t)) return 21;
    if (RegExp(r'\bevening\b').hasMatch(t)) return 18;
    if (RegExp(r'\bafternoon\b').hasMatch(t)) return 14;
    if (RegExp(r'\bmorning\b').hasMatch(t)) return 8;
    if (RegExp(r'\bnight\b').hasMatch(t)) return 21;
    return null;
  }

  static final _clock = RegExp(
    r"\b\d{1,2}(:\d{2})?\s*(a\.?m\.?|p\.?m\.?)(?![a-z])|\bat\s+\d{1,2}(:\d{2})?\b|\b\d{1,2}:\d{2}\b|\bnoon\b|\bmidnight\b|o'clock",
  );

  /// True when the user said a specific clock time ("at 8", "6:30 pm").
  static bool hasExplicitClock(String text) =>
      _clock.hasMatch(text.toLowerCase());

  ResolvedReminder resolve({
    ParsedWhen? at,
    String utterance = '',
    ReminderRepeat? argRepeat,
  }) {
    final said = utterance.trim();
    final repeat = said.isNotEmpty
        ? detectRepeat(said)
        : (argRepeat ?? ReminderRepeat.none);
    final part = dayPartHour(said);
    final explicit = hasExplicitClock(said);

    final today = DateTime(now.year, now.month, now.day);
    final day = (at != null && at.hasDate)
        ? DateTime(at.value.year, at.value.month, at.value.day)
        : today;

    int hour;
    int minute;
    if (part != null && !explicit) {
      hour = part;
      minute = 0;
    } else if (at != null && at.hasTime) {
      hour = at.value.hour;
      minute = at.value.minute;
    } else {
      throw const ToolFollowUp('What time should I set that for?');
    }

    var candidate = DateTime(day.year, day.month, day.day, hour, minute);
    if (!candidate.isAfter(now)) {
      final onToday =
          candidate.year == today.year &&
          candidate.month == today.month &&
          candidate.day == today.day;
      if (onToday) {
        final days = (repeat == ReminderRepeat.weekly && at?.hasDate == true)
            ? 7
            : 1;
        candidate = DateTime(day.year, day.month, day.day + days, hour, minute);
      } else if (repeat != ReminderRepeat.none) {
        candidate = DateTime(today.year, today.month, today.day, hour, minute);
        if (!candidate.isAfter(now)) {
          candidate = DateTime(
            today.year,
            today.month,
            today.day + 1,
            hour,
            minute,
          );
        }
      } else {
        throw const ToolFollowUp(
          'That time has already passed. When should I remind you?',
        );
      }
    }
    return ResolvedReminder(candidate, repeat);
  }
}
