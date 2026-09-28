import '../../core/errors/failures.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/local_task_data_source.dart';
import '../models/task_model.dart';

/// [TaskRepository] implementation backed by local SQLite storage
/// ([LocalTaskDataSource]). Firestore sync is not implemented yet — see
/// docs/architecture.md §8 (offline-first: local DB first, sync later).
class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({LocalTaskDataSource? dataSource})
    : _dataSource = dataSource ?? LocalTaskDataSource();

  final LocalTaskDataSource _dataSource;

  @override
  Future<List<Task>> getTasks(String userId) async {
    try {
      return await _dataSource.getAllTasks(userId);
    } catch (e) {
      throw DatabaseFailure('Failed to load tasks: $e');
    }
  }

  @override
  Future<Task?> getTask(String id) async {
    try {
      return await _dataSource.getTaskById(id);
    } catch (e) {
      throw DatabaseFailure('Failed to load task: $e');
    }
  }

  @override
  Future<Task> createTask(Task task) async {
    try {
      final model = TaskModel.fromEntity(task);
      await _dataSource.insertTask(model);
      return model;
    } catch (e) {
      throw DatabaseFailure('Failed to create task: $e');
    }
  }

  @override
  Future<Task> updateTask(Task task) async {
    try {
      final updated = TaskModel.fromEntity(
        task.copyWith(updatedAt: DateTime.now()),
      );
      final found = await _dataSource.updateTask(updated);
      if (!found) {
        throw DatabaseFailure('Task ${task.id} does not exist.');
      }
      return updated;
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to update task: $e');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      final found = await _dataSource.deleteTask(id);
      if (!found) {
        throw DatabaseFailure('Task $id does not exist.');
      }
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to delete task: $e');
    }
  }

  @override
  Future<Task> completeTask(String id) async {
    try {
      final existing = await _dataSource.getTaskById(id);
      if (existing == null) {
        throw DatabaseFailure('Task $id does not exist.');
      }
      final now = DateTime.now();
      final found = await _dataSource.setCompleted(
        id,
        completed: true,
        updatedAt: now,
      );
      if (!found) {
        throw DatabaseFailure('Task $id does not exist.');
      }
      return existing.copyWith(completed: true, updatedAt: now);
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to complete task: $e');
    }
  }
}
