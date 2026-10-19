/// Plain-language date/time wording for assistant replies. Hand-rolled so it
/// never depends on locale data being initialised.
library;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "9:00 PM"
String clockTime(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "9 PM" or "9:30 PM"
String spokenClock(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final suffix = t.hour < 12 ? 'AM' : 'PM';
  if (t.minute == 0) return '$h12 $suffix';
  return '$h12:${t.minute.toString().padLeft(2, '0')} $suffix';
}

/// "today", "tomorrow" or "Wed 21 Oct".
String dayWord(DateTime t, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (_sameDay(t, today)) return 'today';
  if (_sameDay(t, today.add(const Duration(days: 1)))) return 'tomorrow';
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';
}

/// "today 9:00 PM" - for result cards.
String describeWhen(DateTime t, DateTime now) =>
    '${dayWord(t, now)} ${clockTime(t)}';

/// "9 PM tonight", "8 AM tomorrow", "6:30 PM on Wed 21 Oct" - for speech.
String spokenWhen(DateTime t, DateTime now) {
  final day = dayWord(t, now);
  final clock = spokenClock(t);
  if (day == 'today') {
    return t.hour >= 18 ? '$clock tonight' : '$clock today';
  }
  if (day == 'tomorrow') return '$clock tomorrow';
  return '$clock on $day';
}

/// 1200 -> "1,200", 12.5 -> "12.50".
String formatAmount(double v) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.round().toString() : v.toStringAsFixed(2);
  final parts = s.split('.');
  final digits = parts.first;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
}
