import 'dart:convert';

import '../../domain/entities/life_event.dart';

/// Serialization for [LifeEvent]: SQLite rows and Firestore documents.
///
/// Deleted events are kept as tombstones (`deleted: true`) so a delete on
/// one device propagates to the others and conflicts resolve by
/// `updatedAt` like any other edit.
class LifeEventModel {
  const LifeEventModel(this.event, {this.deleted = false});

  final LifeEvent event;
  final bool deleted;

  Map<String, Object?> toMap() => {
    'id': event.id,
    'uid': event.uid,
    'type': event.type.wire,
    'timestamp': event.timestamp.millisecondsSinceEpoch,
    'metadata': jsonEncode(event.metadata),
    'created_at': event.createdAt.millisecondsSinceEpoch,
    'updated_at': event.updatedAt.millisecondsSinceEpoch,
    'deleted': deleted ? 1 : 0,
  };

  factory LifeEventModel.fromMap(Map<String, Object?> map) {
    final raw = map['metadata'] as String?;
    return LifeEventModel(
      LifeEvent(
        id: map['id']! as String,
        uid: map['uid']! as String,
        type: LifeEventType.fromWire(map['type'] as String?),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp']! as num).toInt(),
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at']! as num).toInt(),
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at']! as num).toInt(),
        ),
        metadata: raw == null || raw.isEmpty
            ? const {}
            : (jsonDecode(raw) as Map).cast<String, dynamic>(),
      ),
      deleted: (map['deleted'] as num?) == 1,
    );
  }

  /// Field names intentionally use ints for times so range queries work
  /// without composite indexes and `updatedAt` is directly comparable
  /// for last-writer-wins.
  Map<String, dynamic> toFirestoreMap() => {
    'uid': event.uid,
    'type': event.type.wire,
    'timestamp': event.timestamp.millisecondsSinceEpoch,
    'metadata': event.metadata,
    'createdAt': event.createdAt.millisecondsSinceEpoch,
    'updatedAt': event.updatedAt.millisecondsSinceEpoch,
    'deleted': deleted,
  };

  factory LifeEventModel.fromFirestoreMap(String id, Map<String, dynamic> m) {
    int ms(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    final ts = ms(m['timestamp'], 0);
    return LifeEventModel(
      LifeEvent(
        id: id,
        uid: (m['uid'] as String?) ?? '',
        type: LifeEventType.fromWire(m['type'] as String?),
        timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
        createdAt: DateTime.fromMillisecondsSinceEpoch(ms(m['createdAt'], ts)),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(ms(m['updatedAt'], ts)),
        metadata: (m['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      deleted: m['deleted'] == true,
    );
  }
}
