import '../../domain/entities/task.dart';

/// Data-layer representation of [Task]: same fields, plus SQLite
/// row (de)serialization. Kept separate from the domain entity so
/// storage concerns (column names, int-encoded bools/enums/timestamps)
/// never leak into domain/presentation code.
class TaskModel extends Task {
  const TaskModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    super.completed,
    super.priority,
    required super.createdAt,
    required super.updatedAt,
    super.dueDate,
  });

  factory TaskModel.fromEntity(Task task) {
    return TaskModel(
      id: task.id,
      userId: task.userId,
      title: task.title,
      description: task.description,
      completed: task.completed,
      priority: task.priority,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      dueDate: task.dueDate,
    );
  }

  factory TaskModel.fromMap(Map<String, Object?> map) {
    DateTime parseDate(Object? val, DateTime fallback) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    DateTime? parseNullableDate(Object? val) {
      if (val == null) return null;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawCompleted = map['completed'];
    final completed = rawCompleted is bool
        ? rawCompleted
        : (rawCompleted is int ? rawCompleted == 1 : false);

    final rawPriority = map['priority'];
    TaskPriority priority = TaskPriority.medium;
    if (rawPriority is String) {
      try {
        priority = TaskPriority.values.byName(rawPriority);
      } catch (_) {}
    }

    final now = DateTime.now();

    return TaskModel(
      id: (map['id'] ?? '') as String,
      userId: ((map['user_id'] ?? map['userId']) ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: map['description'] as String?,
      completed: completed,
      priority: priority,
      createdAt: parseDate(map['created_at'] ?? map['createdAt'], now),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt'], now),
      dueDate: parseNullableDate(map['due_date'] ?? map['dueDate']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority.name,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'completed': completed,
      'priority': priority.name,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
