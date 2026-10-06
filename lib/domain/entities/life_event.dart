/// The kinds of moment OmniPulse can record. Stored by [wire] name.
enum LifeEventType {
  sleepStart('sleep_start'),
  wake('wake'),
  meal('meal'),
  water('water'),
  workout('workout'),
  focus('focus'),
  mood('mood'),
  energy('energy'),
  habit('habit'),
  taskCompleted('task_completed'),
  note('note'),
  custom('custom');

  const LifeEventType(this.wire);
  final String wire;

  static LifeEventType fromWire(String? value) {
    return LifeEventType.values.firstWhere(
      (t) => t.wire == value,
      orElse: () => LifeEventType.custom,
    );
  }
}

/// A single user-recorded moment. Recording must be one tap, so everything
/// except [type] and [timestamp] is optional: [metadata] carries optional
/// detail (e.g. `{'score': 4}` for mood, `{'ml': 250}` for water).
class LifeEvent {
  const LifeEvent({
    required this.id,
    required this.uid,
    required this.type,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  final String id;
  final String uid;
  final LifeEventType type;

  /// When the moment happened (editable, so users can correct a late tap).
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  /// 1-5 mood score when this is a mood event.
  int? get moodScore => type == LifeEventType.mood ? _int('score') : null;

  /// 1-5 energy level when this is an energy event.
  int? get energyLevel => type == LifeEventType.energy ? _int('level') : null;

  String? get label => metadata['label'] as String?;

  int? _int(String key) {
    final v = metadata[key];
    return v is num ? v.toInt() : null;
  }

  LifeEvent copyWith({
    DateTime? timestamp,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return LifeEvent(
      id: id,
      uid: uid,
      type: type,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LifeEvent &&
      other.id == id &&
      other.uid == uid &&
      other.type == type &&
      other.timestamp == timestamp &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, uid, type, timestamp, updatedAt);

  @override
  String toString() => 'LifeEvent(${type.wire} @ $timestamp)';
}
