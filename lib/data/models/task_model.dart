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
    return TaskModel(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      title: map['title']! as String,
      description: map['description'] as String?,
      completed: (map['completed']! as int) == 1,
      priority: TaskPriority.values.byName(map['priority']! as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
      dueDate: map['due_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['due_date']! as int),
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
}
