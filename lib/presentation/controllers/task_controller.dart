import 'package:get/get.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/auth_repository.dart' show AppUser;
import '../../domain/repositories/task_repository.dart';
import 'auth_controller.dart';

enum TaskFilter { all, today, upcoming, completed }

/// Presentation-layer state for task management.
///
/// Coordinates task CRUD operations, filters, and metrics for both
/// the dedicated Tasks screen and the Dashboard widgets.
class TaskController extends GetxController {
  TaskController({
    TaskRepository? taskRepository,
    AuthController? authController,
  })  : _injectedRepository = taskRepository,
        _injectedAuthController = authController;

  final TaskRepository? _injectedRepository;
  final AuthController? _injectedAuthController;

  TaskRepository get _taskRepository =>
      _injectedRepository ?? Get.find<TaskRepository>();
  AuthController get _authController =>
      _injectedAuthController ?? Get.find<AuthController>();

  final tasks = <Task>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  final selectedFilter = TaskFilter.all.obs;
  final selectedPriority = Rxn<TaskPriority>();
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();

    // React to user changes: load tasks when signed in, clear when signed out
    ever<AppUser?>(_authController.currentUser, (user) {
      if (user != null) {
        loadTasks();
      } else {
        tasks.clear();
      }
    });

    if (_authController.currentUser.value != null) {
      loadTasks();
    }
  }

  String get _currentUserId =>
      _authController.currentUser.value?.uid ?? 'guest-user';

  Future<void> loadTasks() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loaded = await _taskRepository.getTasks(_currentUserId);
      tasks.assignAll(loaded);
    } on Failure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to load tasks: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<Task?> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    if (title.trim().isEmpty) return null;

    final now = DateTime.now();
    final newTask = Task(
      id: 'task_${now.millisecondsSinceEpoch}_${now.microsecond}',
      userId: _currentUserId,
      title: title.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      completed: false,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      dueDate: dueDate,
    );

    // Optimistic local add
    tasks.insert(0, newTask);

    try {
      final created = await _taskRepository.createTask(newTask);
      final index = tasks.indexWhere((t) => t.id == newTask.id);
      if (index != -1) {
        tasks[index] = created;
      }
      return created;
    } on Failure catch (e) {
      tasks.removeWhere((t) => t.id == newTask.id);
      errorMessage.value = e.message;
      return null;
    } catch (e) {
      tasks.removeWhere((t) => t.id == newTask.id);
      errorMessage.value = 'Failed to create task: $e';
      return null;
    }
  }

  Future<void> toggleTask(String id) async {
    final index = tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final task = tasks[index];
    final updated = task.copyWith(
      completed: !task.completed,
      updatedAt: DateTime.now(),
    );

    // Optimistic local toggle
    tasks[index] = updated;

    try {
      if (updated.completed) {
        await _taskRepository.completeTask(id);
      } else {
        await _taskRepository.updateTask(updated);
      }
    } catch (_) {
      // Revert if error
      tasks[index] = task;
    }
  }

  Future<void> deleteTask(String id) async {
    final index = tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final removed = tasks.removeAt(index);

    try {
      await _taskRepository.deleteTask(id);
    } catch (_) {
      // Revert if error
      tasks.insert(index, removed);
    }
  }

  Future<void> updateTask(Task task) async {
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;

    final oldTask = tasks[index];
    tasks[index] = task;

    try {
      await _taskRepository.updateTask(task);
    } catch (_) {
      tasks[index] = oldTask;
    }
  }

  void setFilter(TaskFilter filter) => selectedFilter.value = filter;

  void setPriority(TaskPriority? priority) => selectedPriority.value = priority;

  void setSearch(String query) => searchQuery.value = query;

  List<Task> get filteredTasks {
    final query = searchQuery.value.trim().toLowerCase();
    final priority = selectedPriority.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return tasks.where((t) {
      // Priority filter
      if (priority != null && t.priority != priority) return false;

      // Search query filter
      if (query.isNotEmpty) {
        final titleMatch = t.title.toLowerCase().contains(query);
        final descMatch = t.description?.toLowerCase().contains(query) ?? false;
        if (!titleMatch && !descMatch) return false;
      }

      // Tab filter
      switch (selectedFilter.value) {
        case TaskFilter.all:
          return true;
        case TaskFilter.today:
          if (t.dueDate == null) {
            final createdDay = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
            return createdDay == today && !t.completed;
          }
          final taskDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
          return taskDay.isAtSameMomentAs(today) || (taskDay.isBefore(today) && !t.completed);
        case TaskFilter.upcoming:
          if (t.dueDate == null) return false;
          final taskDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
          return taskDay.isAfter(today) && !t.completed;
        case TaskFilter.completed:
          return t.completed;
      }
    }).toList();
  }

  List<Task> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return tasks.where((t) {
      if (t.dueDate == null) {
        final createdDay = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
        return createdDay == today;
      }
      final taskDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return taskDay.isAtSameMomentAs(today) || (taskDay.isBefore(today) && !t.completed);
    }).toList();
  }

  int get completedTodayCount => todayTasks.where((t) => t.completed).length;

  int get totalTodayCount => todayTasks.length;

  double get completionRate =>
      totalTodayCount == 0 ? 0.0 : completedTodayCount / totalTodayCount;
}
