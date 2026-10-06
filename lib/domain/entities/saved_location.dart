import 'package:flutter/foundation.dart';

/// A place the user chose to remember, with a radius that defines the
/// geofence around it. May be linked to a calendar event or a task.
@immutable
class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.createdAt,
    required this.updatedAt,
    this.linkedEventId,
    this.linkedTaskId,
  });

  static const double minRadiusMeters = 20;
  static const double maxRadiusMeters = 5000;
  static const double defaultRadiusMeters = 100;

  final String id;
  final String userId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String? linkedEventId;
  final String? linkedTaskId;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedLocation copyWith({
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? linkedEventId,
    String? linkedTaskId,
    bool clearLinkedEvent = false,
    bool clearLinkedTask = false,
    DateTime? updatedAt,
  }) {
    return SavedLocation(
      id: id,
      userId: userId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      linkedEventId: clearLinkedEvent
          ? null
          : (linkedEventId ?? this.linkedEventId),
      linkedTaskId: clearLinkedTask
          ? null
          : (linkedTaskId ?? this.linkedTaskId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SavedLocation &&
      other.id == id &&
      other.userId == userId &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusMeters == radiusMeters &&
      other.linkedEventId == linkedEventId &&
      other.linkedTaskId == linkedTaskId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    latitude,
    longitude,
    radiusMeters,
    linkedEventId,
    linkedTaskId,
    createdAt,
    updatedAt,
  );
}
