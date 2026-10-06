import '../../domain/entities/saved_location.dart';

/// Serialization for [SavedLocation] (SQLite rows and Firestore documents).
class SavedLocationModel extends SavedLocation {
  const SavedLocationModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.latitude,
    required super.longitude,
    required super.radiusMeters,
    required super.createdAt,
    required super.updatedAt,
    super.linkedEventId,
    super.linkedTaskId,
  });

  factory SavedLocationModel.fromEntity(SavedLocation l) => SavedLocationModel(
    id: l.id,
    userId: l.userId,
    name: l.name,
    latitude: l.latitude,
    longitude: l.longitude,
    radiusMeters: l.radiusMeters,
    linkedEventId: l.linkedEventId,
    linkedTaskId: l.linkedTaskId,
    createdAt: l.createdAt,
    updatedAt: l.updatedAt,
  );

  /// SQLite row (sync flags are managed by the data source, not here).
  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radius_m': radiusMeters,
    'linked_event_id': linkedEventId,
    'linked_task_id': linkedTaskId,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory SavedLocationModel.fromMap(Map<String, Object?> m) =>
      SavedLocationModel(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        radiusMeters: (m['radius_m'] as num).toDouble(),
        linkedEventId: m['linked_event_id'] as String?,
        linkedTaskId: m['linked_task_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );

  /// Firestore document body (document id = [id]).
  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'linkedEventId': linkedEventId,
    'linkedTaskId': linkedTaskId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory SavedLocationModel.fromFirestoreMap(
    String userId,
    Map<String, dynamic> d,
  ) {
    DateTime ts(Object? v) =>
        DateTime.fromMillisecondsSinceEpoch((v as num?)?.toInt() ?? 0);
    return SavedLocationModel(
      id: d['id'] as String,
      userId: userId,
      name: (d['name'] as String?) ?? 'Saved place',
      latitude: (d['latitude'] as num).toDouble(),
      longitude: (d['longitude'] as num).toDouble(),
      radiusMeters:
          (d['radiusMeters'] as num?)?.toDouble() ??
          SavedLocation.defaultRadiusMeters,
      linkedEventId: d['linkedEventId'] as String?,
      linkedTaskId: d['linkedTaskId'] as String?,
      createdAt: ts(d['createdAt']),
      updatedAt: ts(d['updatedAt']),
    );
  }
}
