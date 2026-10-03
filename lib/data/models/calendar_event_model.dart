import '../../domain/entities/calendar_event.dart';

/// Data-layer representation of [CalendarEvent] with SQLite row and Firestore serialization.
class CalendarEventModel extends CalendarEvent {
  const CalendarEventModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    required super.startAt,
    required super.endAt,
    super.isAllDay,
    super.colorTag,
    super.type,
    super.linkedTaskId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory CalendarEventModel.fromEntity(CalendarEvent event) {
    return CalendarEventModel(
      id: event.id,
      userId: event.userId,
      title: event.title,
      description: event.description,
      startAt: event.startAt,
      endAt: event.endAt,
      isAllDay: event.isAllDay,
      colorTag: event.colorTag,
      type: event.type,
      linkedTaskId: event.linkedTaskId,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );
  }

  factory CalendarEventModel.fromMap(Map<String, Object?> map) {
    DateTime parseDate(Object? val, DateTime fallback) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final rawAllDay = map['is_all_day'] ?? map['isAllDay'];
    final isAllDay = rawAllDay is bool
        ? rawAllDay
        : (rawAllDay is int ? rawAllDay == 1 : false);

    final rawType = map['type'];
    CalendarEventType type = CalendarEventType.event;
    if (rawType is String) {
      try {
        type = CalendarEventType.values.byName(rawType);
      } catch (_) {}
    }

    final now = DateTime.now();

    return CalendarEventModel(
      id: (map['id'] ?? '') as String,
      userId: ((map['user_id'] ?? map['userId']) ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: map['description'] as String?,
      startAt: parseDate(map['start_at'] ?? map['startAt'], now),
      endAt: parseDate(
        map['end_at'] ?? map['endAt'],
        now.add(const Duration(hours: 1)),
      ),
      isAllDay: isAllDay,
      colorTag: (map['color_tag'] ?? map['colorTag'] ?? 'blue') as String,
      type: type,
      linkedTaskId: (map['linked_task_id'] ?? map['linkedTaskId']) as String?,
      createdAt: parseDate(map['created_at'] ?? map['createdAt'], now),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt'], now),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'start_at': startAt.millisecondsSinceEpoch,
      'end_at': endAt.millisecondsSinceEpoch,
      'is_all_day': isAllDay ? 1 : 0,
      'color_tag': colorTag,
      'type': type.name,
      'linked_task_id': linkedTaskId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'isAllDay': isAllDay,
      'colorTag': colorTag,
      'type': type.name,
      'linkedTaskId': linkedTaskId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
