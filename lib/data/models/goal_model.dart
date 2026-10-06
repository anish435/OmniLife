import 'dart:convert';

import '../../domain/entities/goal.dart';

class GoalModel extends Goal {
  const GoalModel({
    required super.id,
    required super.userId,
    required super.title,
    super.targetDescription,
    super.targetDate,
    super.linkedHabitId,
    super.milestones,
    required super.createdAt,
    required super.updatedAt,
  });

  factory GoalModel.fromEntity(Goal goal) => GoalModel(
    id: goal.id,
    userId: goal.userId,
    title: goal.title,
    targetDescription: goal.targetDescription,
    targetDate: goal.targetDate,
    linkedHabitId: goal.linkedHabitId,
    milestones: goal.milestones,
    createdAt: goal.createdAt,
    updatedAt: goal.updatedAt,
  );

  static DateTime? _parseNullableDate(Object? val) {
    if (val == null) return null;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    // Firestore Timestamp (has toDate()) without importing cloud_firestore.
    try {
      final d = (val as dynamic).toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }

  static List<GoalMilestone> _parseMilestones(Object? raw) {
    Object? decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    final out = <GoalMilestone>[];
    for (final item in decoded) {
      if (item is Map) {
        final id = item['id']?.toString() ?? '';
        final title = item['title']?.toString() ?? '';
        final done = item['done'];
        if (id.isEmpty) continue;
        out.add(
          GoalMilestone(
            id: id,
            title: title,
            done: done is bool ? done : done == 1,
          ),
        );
      }
    }
    return out;
  }

  factory GoalModel.fromMap(Map<String, Object?> map) {
    final now = DateTime.now();
    final linked = (map['linked_habit_id'] ?? map['linkedHabitId']) as String?;
    return GoalModel(
      id: (map['id'] ?? '') as String,
      userId: ((map['user_id'] ?? map['userId']) ?? '') as String,
      title: (map['title'] ?? '') as String,
      targetDescription:
          ((map['target_description'] ?? map['targetDescription']) ?? '')
              as String,
      targetDate: _parseNullableDate(map['target_date'] ?? map['targetDate']),
      linkedHabitId: (linked == null || linked.isEmpty) ? null : linked,
      milestones: _parseMilestones(map['milestones']),
      createdAt:
          _parseNullableDate(map['created_at'] ?? map['createdAt']) ?? now,
      updatedAt:
          _parseNullableDate(map['updated_at'] ?? map['updatedAt']) ?? now,
    );
  }

  List<Map<String, Object?>> _milestoneMaps() => [
    for (final m in milestones) {'id': m.id, 'title': m.title, 'done': m.done},
  ];

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'target_description': targetDescription,
    'target_date': targetDate?.millisecondsSinceEpoch,
    'linked_habit_id': linkedHabitId,
    'milestones': jsonEncode(_milestoneMaps()),
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  Map<String, dynamic> toFirestoreMap() => {
    'userId': userId,
    'title': title,
    'targetDescription': targetDescription,
    'targetDate': targetDate?.toIso8601String(),
    'linkedHabitId': linkedHabitId,
    'milestones': _milestoneMaps(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
