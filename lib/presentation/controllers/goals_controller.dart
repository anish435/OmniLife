import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/goal_repository_impl.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import 'auth_controller.dart';

class GoalsController extends GetxController {
  GoalsController({
    GoalRepository? goalRepository,
    AuthController? authController,
  }) : _injectedRepository = goalRepository,
       _injectedAuth = authController;

  final GoalRepository? _injectedRepository;
  final AuthController? _injectedAuth;

  GoalRepository get _repository =>
      _injectedRepository ?? Get.find<GoalRepository>();
  AuthController get _auth => _injectedAuth ?? Get.find<AuthController>();

  /// Registers the goal repository and controller on first use. Lives here
  /// (instead of in initial_binding) so the Habits screens can be opened
  /// from any route without touching shared binding files.
  static GoalsController ensureRegistered() {
    if (!Get.isRegistered<GoalRepository>()) {
      Get.lazyPut<GoalRepository>(() => GoalRepositoryImpl(), fenix: true);
    }
    if (!Get.isRegistered<GoalsController>()) {
      Get.put(GoalsController(), permanent: true);
    }
    return Get.find<GoalsController>();
  }

  final goals = <Goal>[].obs;
  final isLoading = false.obs;
  final errorMessage = Rx<String?>(null);

  String get _userId => _auth.currentUser.value?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    ever(_auth.currentUser, (_) => loadGoals());
    if (_auth.currentUser.value != null) loadGoals();
  }

  Future<void> loadGoals() async {
    if (_userId.isEmpty) {
      goals.clear();
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      goals.assignAll(await _repository.getGoals(_userId));
    } catch (e) {
      errorMessage.value = 'Failed to load goals: $e';
    } finally {
      isLoading.value = false;
    }
  }

  List<Goal> goalsForHabit(String habitId) =>
      goals.where((g) => g.linkedHabitId == habitId).toList();

  Future<Goal?> createGoal({
    required String title,
    String targetDescription = '',
    DateTime? targetDate,
    String? linkedHabitId,
    List<String> milestoneTitles = const [],
  }) async {
    if (_userId.isEmpty || title.trim().isEmpty) return null;
    final now = DateTime.now();
    final goal = Goal(
      id: const Uuid().v4(),
      userId: _userId,
      title: title.trim(),
      targetDescription: targetDescription.trim(),
      targetDate: targetDate,
      linkedHabitId: linkedHabitId,
      milestones: [
        for (final t in milestoneTitles)
          if (t.trim().isNotEmpty)
            GoalMilestone(id: const Uuid().v4(), title: t.trim()),
      ],
      createdAt: now,
      updatedAt: now,
    );
    goals.add(goal);
    try {
      final created = await _repository.createGoal(goal);
      final i = goals.indexWhere((g) => g.id == goal.id);
      if (i != -1) goals[i] = created;
      return created;
    } catch (e) {
      goals.removeWhere((g) => g.id == goal.id);
      errorMessage.value = 'Failed to create goal: $e';
      return null;
    }
  }

  Future<bool> updateGoal(Goal goal) async {
    final updated = goal.copyWith(updatedAt: DateTime.now());
    final i = goals.indexWhere((g) => g.id == goal.id);
    if (i == -1) return false;
    final previous = goals[i];
    goals[i] = updated;
    try {
      await _repository.updateGoal(updated);
      return true;
    } catch (e) {
      final j = goals.indexWhere((g) => g.id == goal.id);
      if (j != -1) goals[j] = previous;
      errorMessage.value = 'Failed to update goal: $e';
      return false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    final i = goals.indexWhere((g) => g.id == id);
    if (i == -1) return false;
    final removed = goals.removeAt(i);
    try {
      await _repository.deleteGoal(id);
      return true;
    } catch (e) {
      goals.insert(i.clamp(0, goals.length), removed);
      errorMessage.value = 'Failed to delete goal: $e';
      return false;
    }
  }

  /// Flips one milestone and persists. Returns the updated goal or null.
  Future<Goal?> toggleMilestone(String goalId, String milestoneId) async {
    final goal = goals.firstWhereOrNull((g) => g.id == goalId);
    if (goal == null) return null;
    final next = goal.copyWith(
      milestones: [
        for (final m in goal.milestones)
          if (m.id == milestoneId) m.copyWith(done: !m.done) else m,
      ],
    );
    final ok = await updateGoal(next);
    return ok ? goals.firstWhereOrNull((g) => g.id == goalId) : null;
  }

  /// Called when a habit is deleted: its goals stay but lose the link.
  Future<void> unlinkHabit(String habitId) async {
    for (final g in goalsForHabit(habitId)) {
      await updateGoal(g.copyWith(clearLinkedHabit: true));
    }
  }
}
