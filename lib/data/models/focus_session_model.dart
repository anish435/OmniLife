import '../../domain/entities/focus_session.dart';

/// Storage representation of [FocusSession] (SQLite row and Firestore map).
class FocusSessionModel extends FocusSession {
  const FocusSessionModel({
    required super.id,
    required super.userId,
    required super.startedAt,
    required super.endedAt,
    required super.plannedSeconds,
    required super.focusedSeconds,
    super.completed,
  });

  factory FocusSessionModel.fromEntity(FocusSession s) => FocusSessionModel(
    id: s.id,
    userId: s.userId,
    startedAt: s.startedAt,
    endedAt: s.endedAt,
    plannedSeconds: s.plannedSeconds,
    focusedSeconds: s.focusedSeconds,
    completed: s.completed,
  );

  factory FocusSessionModel.fromMap(Map<String, Object?> map) {
    DateTime date(Object? v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      // Firestore Timestamp exposes toDate().
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    final done = map['completed'];
    return FocusSessionModel(
      id: map['id'] as String,
      userId: (map['user_id'] ?? map['userId'] ?? '') as String,
      startedAt: date(map['started_at'] ?? map['startedAt']),
      endedAt: date(map['ended_at'] ?? map['endedAt']),
      plannedSeconds:
          ((map['planned_seconds'] ?? map['plannedSeconds'] ?? 0) as num)
              .toInt(),
      focusedSeconds:
          ((map['focused_seconds'] ?? map['focusedSeconds'] ?? 0) as num)
              .toInt(),
      completed: done is bool ? done : done == 1,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'started_at': startedAt.millisecondsSinceEpoch,
    'ended_at': endedAt.millisecondsSinceEpoch,
    'planned_seconds': plannedSeconds,
    'focused_seconds': focusedSeconds,
    'completed': completed ? 1 : 0,
  };

  Map<String, dynamic> toFirestoreMap() => {
    'userId': userId,
    'startedAt': startedAt.toUtc().millisecondsSinceEpoch,
    'endedAt': endedAt.toUtc().millisecondsSinceEpoch,
    'plannedSeconds': plannedSeconds,
    'focusedSeconds': focusedSeconds,
    'completed': completed,
  };
}
