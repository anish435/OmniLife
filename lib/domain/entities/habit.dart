import 'package:equatable/equatable.dart';

enum HabitFrequency { daily, weekly, specificDays }

class Habit extends Equatable {
  const Habit({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.frequency = HabitFrequency.daily,
    this.targetDaysPerWeek = 7,
    this.specificDays = const [], // e.g., [1, 3, 5] for Mon, Wed, Fri
    this.colorTag = 'default',
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final HabitFrequency frequency;
  final int targetDaysPerWeek;
  final List<int> specificDays;
  final String colorTag;
  final int currentStreak;
  final int longestStreak;
  final DateTime createdAt;
  final DateTime updatedAt;

  Habit copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    HabitFrequency? frequency,
    int? targetDaysPerWeek,
    List<int>? specificDays,
    String? colorTag,
    int? currentStreak,
    int? longestStreak,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Habit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      specificDays: specificDays ?? this.specificDays,
      colorTag: colorTag ?? this.colorTag,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        frequency,
        targetDaysPerWeek,
        specificDays,
        colorTag,
        currentStreak,
        longestStreak,
        createdAt,
        updatedAt,
      ];
}

class HabitLog extends Equatable {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date, // Store as YYYY-MM-DD
    this.isCompleted = true,
  });

  final String id;
  final String habitId;
  final String date;
  final bool isCompleted;

  HabitLog copyWith({
    String? id,
    String? habitId,
    String? date,
    bool? isCompleted,
  }) {
    return HabitLog(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [id, habitId, date, isCompleted];
}
