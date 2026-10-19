import '../../domain/entities/reminder.dart';

/// Serialization for [Reminder]: SQLite rows and Firestore documents.
/// Times are stored as epoch milliseconds so they compare directly for
/// last-writer-wins.
class ReminderModel {
  const ReminderModel(this.reminder);

  final Reminder reminder;

  static ReminderRepeat repeatFromWire(Object? raw) {
    for (final r in ReminderRepeat.values) {
      if (r.name == raw) return r;
    }
    return ReminderRepeat.none;
  }

  Map<String, Object?> toMap() => {
    'id': reminder.id,
    'user_id': reminder.userId,
    'title': reminder.title,
    'scheduled_at': reminder.scheduledAt.millisecondsSinceEpoch,
    'repeat': reminder.repeat.name,
    'note': reminder.note,
    'enabled': reminder.enabled ? 1 : 0,
    'created_at': reminder.createdAt.millisecondsSinceEpoch,
    'updated_at': reminder.updatedAt.millisecondsSinceEpoch,
  };

  factory ReminderModel.fromMap(Map<String, Object?> map) {
    DateTime ms(String key) =>
        DateTime.fromMillisecondsSinceEpoch((map[key]! as num).toInt());
    return ReminderModel(
      Reminder(
        id: map['id']! as String,
        userId: map['user_id']! as String,
        title: map['title']! as String,
        scheduledAt: ms('scheduled_at'),
        repeat: repeatFromWire(map['repeat']),
        note: map['note'] as String?,
        enabled: (map['enabled'] as num?) != 0,
        createdAt: ms('created_at'),
        updatedAt: ms('updated_at'),
      ),
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
    'id': reminder.id,
    'userId': reminder.userId,
    'title': reminder.title,
    'scheduledAt': reminder.scheduledAt.millisecondsSinceEpoch,
    'repeat': reminder.repeat.name,
    'note': reminder.note,
    'enabled': reminder.enabled,
    'createdAt': reminder.createdAt.millisecondsSinceEpoch,
    'updatedAt': reminder.updatedAt.millisecondsSinceEpoch,
  };

  factory ReminderModel.fromFirestoreMap(String id, Map<String, dynamic> m) {
    int ms(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    final at = ms(m['scheduledAt'], 0);
    return ReminderModel(
      Reminder(
        id: id,
        userId: (m['userId'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(at),
        repeat: repeatFromWire(m['repeat']),
        note: m['note'] as String?,
        enabled: m['enabled'] != false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(ms(m['createdAt'], at)),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(ms(m['updatedAt'], at)),
      ),
    );
  }
}
