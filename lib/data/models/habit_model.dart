import 'dart:convert';
import '../../domain/entities/habit.dart';

class HabitModel extends Habit {
  const HabitModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    super.frequency,
    super.targetDaysPerWeek,
    super.specificDays,
    super.colorTag,
    super.currentStreak,
    super.longestStreak,
    required super.createdAt,
    required super.updatedAt,
  });

  factory HabitModel.fromEntity(Habit habit) {
    return HabitModel(
      id: habit.id,
      userId: habit.userId,
      title: habit.title,
      description: habit.description,
      frequency: habit.frequency,
      targetDaysPerWeek: habit.targetDaysPerWeek,
      specificDays: habit.specificDays,
      colorTag: habit.colorTag,
      currentStreak: habit.currentStreak,
      longestStreak: habit.longestStreak,
      createdAt: habit.createdAt,
      updatedAt: habit.updatedAt,
    );
  }

  factory HabitModel.fromMap(Map<String, Object?> map) {
    DateTime parseDate(Object? val, DateTime fallback) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final freqStr = (map['frequency'] as String?) ?? 'daily';
    final frequency = HabitFrequency.values.firstWhere(
      (e) => e.name == freqStr,
      orElse: () => HabitFrequency.daily,
    );

    List<int> specificDays = [];
    final rawDays = map['specific_days'] ?? map['specificDays'];
    if (rawDays is String) {
      try {
        final decoded = jsonDecode(rawDays);
        if (decoded is List) {
          specificDays = decoded.map((e) => int.tryParse(e.toString()) ?? 1).toList();
        }
      } catch (_) {}
    } else if (rawDays is List) {
      specificDays = rawDays.map((e) => int.tryParse(e.toString()) ?? 1).toList();
    }

    final now = DateTime.now();

    return HabitModel(
      id: (map['id'] ?? '') as String,
      userId: ((map['user_id'] ?? map['userId']) ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      frequency: frequency,
      targetDaysPerWeek: (map['target_days_per_week'] ?? map['targetDaysPerWeek'] ?? 7) as int,
      specificDays: specificDays,
      colorTag: (map['color_tag'] ?? map['colorTag'] ?? 'default') as String,
      currentStreak: (map['current_streak'] ?? map['currentStreak'] ?? 0) as int,
      longestStreak: (map['longest_streak'] ?? map['longestStreak'] ?? 0) as int,
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
      'frequency': frequency.name,
      'target_days_per_week': targetDaysPerWeek,
      'specific_days': jsonEncode(specificDays),
      'color_tag': colorTag,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'frequency': frequency.name,
      'targetDaysPerWeek': targetDaysPerWeek,
      'specificDays': specificDays,
      'colorTag': colorTag,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class HabitLogModel extends HabitLog {
  const HabitLogModel({
    required super.id,
    required super.habitId,
    required super.date,
    super.isCompleted,
  });

  factory HabitLogModel.fromEntity(HabitLog log) {
    return HabitLogModel(
      id: log.id,
      habitId: log.habitId,
      date: log.date,
      isCompleted: log.isCompleted,
    );
  }

  factory HabitLogModel.fromMap(Map<String, Object?> map) {
    final rawCompleted = map['is_completed'] ?? map['isCompleted'];
    final isCompleted = rawCompleted is bool ? rawCompleted : (rawCompleted == 1);

    return HabitLogModel(
      id: (map['id'] ?? '') as String,
      habitId: ((map['habit_id'] ?? map['habitId']) ?? '') as String,
      date: (map['date'] ?? '') as String,
      isCompleted: isCompleted,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'date': date,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'habitId': habitId,
      'date': date,
      'isCompleted': isCompleted,
    };
  }
}
