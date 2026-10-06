import '../entities/goal.dart';

abstract class GoalRepository {
  Future<List<Goal>> getGoals(String userId);

  Future<Goal> createGoal(Goal goal);

  Future<Goal> updateGoal(Goal goal);

  Future<void> deleteGoal(String goalId);
}
