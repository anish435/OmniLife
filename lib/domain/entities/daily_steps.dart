import 'package:flutter/foundation.dart';

/// Step total for one local calendar day.
@immutable
class DailySteps {
  const DailySteps({required this.date, required this.steps});

  /// Midnight (local) of the day.
  final DateTime date;
  final int steps;

  /// `yyyy-MM-dd`, also the Firestore document id under
  /// `users/{uid}/sensor_daily`.
  String get key => dayKey(date);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime parseKey(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  @override
  bool operator ==(Object other) =>
      other is DailySteps && other.key == key && other.steps == steps;

  @override
  int get hashCode => Object.hash(key, steps);

  @override
  String toString() => 'DailySteps($key, $steps)';
}
