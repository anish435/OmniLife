import '../../domain/entities/wellness_log.dart';

class WellnessLogModel extends WellnessLog {
  const WellnessLogModel({
    required super.id,
    required super.date,
    super.waterIntakeMl,
    super.sleepDurationHours,
    super.sleepQuality,
    super.workoutDurationMinutes,
    super.workoutType,
    super.moodScore,
    super.synced,
  });

  factory WellnessLogModel.fromEntity(WellnessLog entity) {
    return WellnessLogModel(
      id: entity.id,
      date: entity.date,
      waterIntakeMl: entity.waterIntakeMl,
      sleepDurationHours: entity.sleepDurationHours,
      sleepQuality: entity.sleepQuality,
      workoutDurationMinutes: entity.workoutDurationMinutes,
      workoutType: entity.workoutType,
      moodScore: entity.moodScore,
      synced: entity.synced,
    );
  }

  factory WellnessLogModel.fromMap(Map<String, dynamic> map) {
    return WellnessLogModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      waterIntakeMl: map['waterIntakeMl'] ?? 0,
      sleepDurationHours: (map['sleepDurationHours'] ?? 0).toDouble(),
      sleepQuality: map['sleepQuality'] ?? 3,
      workoutDurationMinutes: map['workoutDurationMinutes'] ?? 0,
      workoutType: map['workoutType'] ?? 'None',
      moodScore: map['moodScore'] ?? 3,
      synced: (map['synced'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'waterIntakeMl': waterIntakeMl,
      'sleepDurationHours': sleepDurationHours,
      'sleepQuality': sleepQuality,
      'workoutDurationMinutes': workoutDurationMinutes,
      'workoutType': workoutType,
      'moodScore': moodScore,
      'synced': synced ? 1 : 0,
    };
  }

  factory WellnessLogModel.fromFirestoreMap(Map<String, dynamic> map, String id) {
    return WellnessLogModel(
      id: id,
      date: DateTime.parse(map['date']),
      waterIntakeMl: map['waterIntakeMl'] ?? 0,
      sleepDurationHours: (map['sleepDurationHours'] ?? 0).toDouble(),
      sleepQuality: map['sleepQuality'] ?? 3,
      workoutDurationMinutes: map['workoutDurationMinutes'] ?? 0,
      workoutType: map['workoutType'] ?? 'None',
      moodScore: map['moodScore'] ?? 3,
      synced: true,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'date': date.toIso8601String(),
      'waterIntakeMl': waterIntakeMl,
      'sleepDurationHours': sleepDurationHours,
      'sleepQuality': sleepQuality,
      'workoutDurationMinutes': workoutDurationMinutes,
      'workoutType': workoutType,
      'moodScore': moodScore,
    };
  }
}
