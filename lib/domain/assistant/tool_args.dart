/// Defensive argument reading for model-supplied tool arguments.
library;

/// The model gave arguments we can't use. [message] is user-safe.
class ToolArgException implements Exception {
  const ToolArgException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The request is missing something needed to act safely. The assistant
/// asks [question] instead of guessing.
class ToolFollowUp implements Exception {
  const ToolFollowUp(this.question);
  final String question;

  @override
  String toString() => question;
}

/// A date/time the model supplied, remembering which parts it included.
class ParsedWhen {
  const ParsedWhen(this.value, {required this.hasDate, required this.hasTime});

  final DateTime value;
  final bool hasDate;
  final bool hasTime;
}

class ToolArgs {
  const ToolArgs(this.raw);

  final Map<String, dynamic> raw;

  bool has(String key) => raw[key] != null && '${raw[key]}'.trim().isNotEmpty;

  String? string(String key, {int maxLength = 200, bool required = false}) {
    final v = raw[key];
    if (v == null || (v is String && v.trim().isEmpty)) {
      if (required) throw ToolArgException('I need a $key for that.');
      return null;
    }
    if (v is! String && v is! num && v is! bool) {
      throw ToolArgException('I didn\'t understand the $key.');
    }
    final s = '$v'.trim();
    if (s.length > maxLength) {
      throw ToolArgException('That $key is too long.');
    }
    return s;
  }

  /// Accepts numbers and numeric strings ("200", "1,200.50").
  double? number(
    String key, {
    double? min,
    double? max,
    bool required = false,
  }) {
    final v = raw[key];
    if (v == null || (v is String && v.trim().isEmpty)) {
      if (required) throw ToolArgException('I need the $key for that.');
      return null;
    }
    double? n;
    if (v is num) {
      n = v.toDouble();
    } else if (v is String) {
      n = double.tryParse(v.replaceAll(',', '').trim());
    }
    if (n == null || n.isNaN || n.isInfinite) {
      throw ToolArgException('I didn\'t understand the $key.');
    }
    if ((min != null && n < min) || (max != null && n > max)) {
      throw ToolArgException('That $key looks out of range.');
    }
    return n;
  }

  bool? boolean(String key) {
    final v = raw[key];
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == 'yes') return true;
      if (s == 'false' || s == 'no') return false;
    }
    return null;
  }

  /// One of [allowed] (case-insensitive) or null when absent.
  String? oneOf(String key, List<String> allowed) {
    final v = raw[key];
    if (v == null || (v is String && v.trim().isEmpty)) return null;
    final s = '$v'.trim().toLowerCase();
    if (!allowed.contains(s)) {
      throw ToolArgException('I didn\'t understand the $key.');
    }
    return s;
  }

  /// Parses ISO-8601 local date-times (`2026-10-19T21:00`), dates
  /// (`2026-10-19`) and bare times (`21:00`). Offsets are converted to
  /// local time. Years outside 2000-2100 are rejected as nonsense.
  ParsedWhen? when(String key, {DateTime? now}) {
    final v = raw[key];
    if (v == null || (v is String && v.trim().isEmpty)) return null;
    if (v is! String) throw ToolArgException('I didn\'t understand the $key.');
    return parseWhen(v, now: now);
  }

  static final _timeOnly = RegExp(r'^T?(\d{1,2}):(\d{2})(?::\d{2})?$');
  static final _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static ParsedWhen parseWhen(String input, {DateTime? now}) {
    final s = input.trim();
    final t = _timeOnly.firstMatch(s);
    if (t != null) {
      final h = int.parse(t.group(1)!);
      final m = int.parse(t.group(2)!);
      if (h > 23 || m > 59) {
        throw const ToolArgException('That time doesn\'t look right.');
      }
      final base = now ?? DateTime.now();
      return ParsedWhen(
        DateTime(base.year, base.month, base.day, h, m),
        hasDate: false,
        hasTime: true,
      );
    }
    final parsed = DateTime.tryParse(s);
    if (parsed == null) {
      throw const ToolArgException('I couldn\'t read that date.');
    }
    if (parsed.year < 2000 || parsed.year > 2100) {
      throw const ToolArgException('That date doesn\'t look right.');
    }
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return ParsedWhen(local, hasDate: true, hasTime: !_dateOnly.hasMatch(s));
  }
}
