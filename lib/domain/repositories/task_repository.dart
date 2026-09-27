import '../entities/task.dart';

/// Domain-facing contract for task persistence.
///
/// Implementations live in the data layer. UI/state-management code must
/// depend on this interface, never on SQLite/Firestore directly — per
/// docs/architecture.md §7 (repository boundary).
abstract class TaskRepository {
  /// All tasks belonging to [userId].
  Future<List<Task>> getTasks(String userId);

  /// A single task by id, or `null` if it doesn't exist.
  Future<Task?> getTask(String id);

  Future<Task> createTask(Task task);

  Future<Task> updateTask(Task task);

  Future<void> deleteTask(String id);

  /// Marks a task completed and returns the updated task.
  Future<Task> completeTask(String id);
}
