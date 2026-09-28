/// Task urgency. Kept as an enum (not a raw int/string) so invalid
/// priority values can't exist and every layer agrees on the same set.
enum TaskPriority { low, medium, high }

/// A single actionable item, per docs/architecture.md §6.
///
/// Framework-agnostic: no SQLite or Firebase types here. [TaskModel] (data
/// layer) is responsible for serializing this to/from storage.
class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.completed = false,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final bool completed;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;

  Task copyWith({
    String? title,
    String? description,
    bool? completed,
    TaskPriority? priority,
    DateTime? updatedAt,
    DateTime? dueDate,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Task &&
            other.id == id &&
            other.userId == userId &&
            other.title == title &&
            other.description == description &&
            other.completed == completed &&
            other.priority == priority &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.dueDate == dueDate);
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    description,
    completed,
    priority,
    createdAt,
    updatedAt,
    dueDate,
  );

  @override
  String toString() => 'Task(id: $id, title: $title, completed: $completed)';
}
