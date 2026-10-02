import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/task_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([this._current]);

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  void emit(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    late StreamController<AppUser?> sc;
    sc = StreamController<AppUser?>.broadcast(
      onListen: () {
        sc.add(_current);
        final sub = _controller.stream.listen(sc.add);
        sc.onCancel = () => sub.cancel();
      },
    );
    return sc.stream;
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> register({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<AppUser> login({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<AppUser> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<void> logout() async {
    emit(null);
  }
}

class FakeTaskRepository implements TaskRepository {
  final List<Task> storage = [];

  @override
  Future<List<Task>> getTasks(String userId) async {
    return storage.where((t) => t.userId == userId).toList();
  }

  @override
  Future<Task?> getTask(String id) async {
    return storage.firstWhereOrNull((t) => t.id == id);
  }

  @override
  Future<Task> createTask(Task task) async {
    storage.add(task);
    return task;
  }

  @override
  Future<Task> updateTask(Task task) async {
    final idx = storage.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      storage[idx] = task;
    }
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    storage.removeWhere((t) => t.id == id);
  }

  @override
  Future<Task> completeTask(String id) async {
    final idx = storage.indexWhere((t) => t.id == id);
    final updated = storage[idx].copyWith(completed: true);
    storage[idx] = updated;
    return updated;
  }
}

void main() {
  late FakeAuthRepository authRepo;
  late AuthController authController;
  late FakeTaskRepository taskRepo;
  late TaskController taskController;

  const testUser = AppUser(uid: 'user-123', email: 'test@example.com');

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    authRepo = FakeAuthRepository(testUser);
    authController = AuthController(authRepository: authRepo);
    authController.onInit();
    await Future<void>.delayed(Duration.zero);
    taskRepo = FakeTaskRepository();
    taskController = TaskController(
      taskRepository: taskRepo,
      authController: authController,
    );
    taskController.onInit();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    Get.reset();
  });

  test('loadTasks populates tasks for the authenticated user', () async {
    final task = Task(
      id: 'task-1',
      userId: testUser.uid,
      title: 'Buy groceries',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await taskRepo.createTask(task);

    await taskController.loadTasks();

    expect(taskController.tasks.length, 1);
    expect(taskController.tasks.first.title, 'Buy groceries');
  });

  test('createTask inserts task both in repo and controller list', () async {
    final created = await taskController.createTask(
      title: 'Complete assignment',
      description: 'Finish math problems',
      priority: TaskPriority.high,
    );

    expect(created, isNotNull);
    expect(taskController.tasks.length, 1);
    expect(taskController.tasks.first.title, 'Complete assignment');
    expect(taskController.tasks.first.priority, TaskPriority.high);
    expect(taskRepo.storage.length, 1);
  });

  test('toggleTask toggles completion status optimistically and in repo', () async {
    await taskController.createTask(title: 'Read a book');
    final task = taskController.tasks.first;
    expect(task.completed, isFalse);

    await taskController.toggleTask(task.id);
    expect(taskController.tasks.first.completed, isTrue);
    expect(taskRepo.storage.first.completed, isTrue);

    await taskController.toggleTask(task.id);
    expect(taskController.tasks.first.completed, isFalse);
    expect(taskRepo.storage.first.completed, isFalse);
  });

  test('deleteTask removes task from state and repository', () async {
    await taskController.createTask(title: 'Temp task');
    final taskId = taskController.tasks.first.id;

    await taskController.deleteTask(taskId);

    expect(taskController.tasks.isEmpty, isTrue);
    expect(taskRepo.storage.isEmpty, isTrue);
  });

  test('updateTask edits task fields accurately', () async {
    await taskController.createTask(title: 'Old title');
    final task = taskController.tasks.first;

    final updated = task.copyWith(title: 'New title', priority: TaskPriority.high);
    await taskController.updateTask(updated);

    expect(taskController.tasks.first.title, 'New title');
    expect(taskController.tasks.first.priority, TaskPriority.high);
    expect(taskRepo.storage.first.title, 'New title');
  });

  test('filters and search queries filter filteredTasks correctly', () async {
    final now = DateTime.now();
    await taskController.createTask(
      title: 'Buy apples',
      dueDate: DateTime(now.year, now.month, now.day, 12),
      priority: TaskPriority.low,
    );
    await taskController.createTask(
      title: 'Fix website bug',
      dueDate: now.add(const Duration(days: 3)),
      priority: TaskPriority.high,
    );

    // Initial state: all
    expect(taskController.filteredTasks.length, 2);

    // Filter today
    taskController.setFilter(TaskFilter.today);
    expect(taskController.filteredTasks.length, 1);
    expect(taskController.filteredTasks.first.title, 'Buy apples');

    // Filter upcoming
    taskController.setFilter(TaskFilter.upcoming);
    expect(taskController.filteredTasks.length, 1);
    expect(taskController.filteredTasks.first.title, 'Fix website bug');

    // Filter priority
    taskController.setFilter(TaskFilter.all);
    taskController.setPriority(TaskPriority.high);
    expect(taskController.filteredTasks.length, 1);
    expect(taskController.filteredTasks.first.title, 'Fix website bug');

    // Reset priority & search query
    taskController.setPriority(null);
    taskController.setSearch('apples');
    expect(taskController.filteredTasks.length, 1);
    expect(taskController.filteredTasks.first.title, 'Buy apples');
  });

  test('todayMetrics and completionRate compute correctly', () async {
    final now = DateTime.now();
    await taskController.createTask(
      title: 'Task 1',
      dueDate: now,
    );
    await taskController.createTask(
      title: 'Task 2',
      dueDate: now,
    );

    expect(taskController.todayTasks.length, 2);
    expect(taskController.completionRate, 0.0);

    await taskController.toggleTask(taskController.todayTasks.first.id);
    expect(taskController.completionRate, 0.5);
    expect(taskController.completedTodayCount, 1);
    expect(taskController.totalTodayCount, 2);
  });

  test('clears tasks on sign out and reloads on sign in', () async {
    await taskController.createTask(title: 'Active task');
    expect(taskController.tasks.length, 1);

    // Sign out
    authRepo.emit(null);
    await Future<void>.delayed(Duration.zero);
    expect(taskController.tasks.isEmpty, isTrue);

    // Sign back in
    authRepo.emit(testUser);
    await Future<void>.delayed(Duration.zero);
    expect(taskController.tasks.length, 1);
    expect(taskController.tasks.first.title, 'Active task');
  });
}
