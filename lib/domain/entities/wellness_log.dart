import 'package:equatable/equatable.dart';

class WellnessLog extends Equatable {
  final String id;
  final DateTime date; // Normalized to 00:00:00 for the day
  final int waterIntakeMl;
  final double sleepDurationHours;
  final int sleepQuality; // 1-5
  final int workoutDurationMinutes;
  final String workoutType; // e.g. "Cardio", "Strength", "Yoga", "None"
  final int moodScore; // 1-5
  final bool synced;

  const WellnessLog({
    required this.id,
    required this.date,
    this.waterIntakeMl = 0,
    this.sleepDurationHours = 0.0,
    this.sleepQuality = 3,
    this.workoutDurationMinutes = 0,
    this.workoutType = 'None',
    this.moodScore = 3,
    this.synced = false,
  });

  WellnessLog copyWith({
    String? id,
    DateTime? date,
    int? waterIntakeMl,
    double? sleepDurationHours,
    int? sleepQuality,
    int? workoutDurationMinutes,
    String? workoutType,
    int? moodScore,
    bool? synced,
  }) {
    return WellnessLog(
      id: id ?? this.id,
      date: date ?? this.date,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      sleepDurationHours: sleepDurationHours ?? this.sleepDurationHours,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      workoutDurationMinutes: workoutDurationMinutes ?? this.workoutDurationMinutes,
      workoutType: workoutType ?? this.workoutType,
      moodScore: moodScore ?? this.moodScore,
      synced: synced ?? this.synced,
    );
  }

  @override
  List<Object?> get props => [
        id,
        date,
        waterIntakeMl,
        sleepDurationHours,
        sleepQuality,
        workoutDurationMinutes,
        workoutType,
        moodScore,
        synced,
      ];
}
