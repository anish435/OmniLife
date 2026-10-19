import 'package:equatable/equatable.dart';

enum ReminderRepeat { none, daily, weekly }

/// A reminder that fires at [scheduledAt] and, when [repeat] is not none,
/// again at the same time of day (daily) or on the same weekday (weekly).
class Reminder extends Equatable {
  const Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.scheduledAt,
    this.repeat = ReminderRepeat.none,
    this.note,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime scheduledAt;
  final ReminderRepeat repeat;
  final String? note;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Next time this reminder fires strictly after [from], or null when a
  /// one-off reminder has already passed.
  DateTime? nextFire(DateTime from) {
    if (!enabled) return null;
    if (scheduledAt.isAfter(from)) return scheduledAt;
    switch (repeat) {
      case ReminderRepeat.none:
        return null;
      case ReminderRepeat.daily:
        var t = DateTime(
          from.year,
          from.month,
          from.day,
          scheduledAt.hour,
          scheduledAt.minute,
        );
        if (!t.isAfter(from)) t = t.add(const Duration(days: 1));
        return t;
      case ReminderRepeat.weekly:
        var t = DateTime(
          from.year,
          from.month,
          from.day,
          scheduledAt.hour,
          scheduledAt.minute,
        );
        while (t.weekday != scheduledAt.weekday || !t.isAfter(from)) {
          t = t.add(const Duration(days: 1));
        }
        return t;
    }
  }

  Reminder copyWith({
    String? title,
    DateTime? scheduledAt,
    ReminderRepeat? repeat,
    String? note,
    bool? enabled,
    DateTime? updatedAt,
  }) => Reminder(
    id: id,
    userId: userId,
    title: title ?? this.title,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    repeat: repeat ?? this.repeat,
    note: note ?? this.note,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    scheduledAt,
    repeat,
    note,
    enabled,
    createdAt,
    updatedAt,
  ];
}
