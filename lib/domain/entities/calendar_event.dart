enum CalendarEventType { event, focusBlock }

/// Immutable domain entity representing a scheduled calendar event or focus block.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.startAt,
    required this.endAt,
    this.isAllDay = false,
    this.colorTag = 'blue',
    this.type = CalendarEventType.event,
    this.linkedTaskId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime endAt;
  final bool isAllDay;

  /// Semantic color key: 'blue', 'emerald', 'amber', 'rose', 'purple', 'slate'.
  final String colorTag;

  final CalendarEventType type;

  /// Optional ID of a task associated with this event/block.
  final String? linkedTaskId;

  final DateTime createdAt;
  final DateTime updatedAt;

  Duration get duration => endAt.difference(startAt);

  CalendarEvent copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    String? colorTag,
    CalendarEventType? type,
    String? linkedTaskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isAllDay: isAllDay ?? this.isAllDay,
      colorTag: colorTag ?? this.colorTag,
      type: type ?? this.type,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarEvent &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.description == description &&
        other.startAt == startAt &&
        other.endAt == endAt &&
        other.isAllDay == isAllDay &&
        other.colorTag == colorTag &&
        other.type == type &&
        other.linkedTaskId == linkedTaskId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        title,
        description,
        startAt,
        endAt,
        isAllDay,
        colorTag,
        type,
        linkedTaskId,
        createdAt,
        updatedAt,
      );
}
