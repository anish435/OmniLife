import '../entities/daily_steps.dart';

/// Step data for the signed-in user. Consumed by the Sensors screen and,
/// later, by OmniPulse and analytics.
///
/// Totals are kept per day and per hour locally, and each changed day is
/// synced (idempotently, as totals not increments) to
/// `users/{uid}/sensor_daily/{yyyy-MM-dd}`.
abstract class StepsRepository {
  /// Steps so far today (0 when none recorded).
  Future<int> todaySteps();

  /// The last 7 local days ending today, oldest first, zero-filled.
  Future<List<DailySteps>> last7Days();

  /// Emits today's total immediately, then after every change.
  Stream<int> watchTodaySteps();

  /// Emits the 7-day series immediately, then after every change.
  Stream<List<DailySteps>> watchLast7Days();

  /// Hour (0-23) -> steps for [day].
  Future<Map<int, int>> hourlySteps(DateTime day);

  /// Feeds a cumulative pedometer reading. Handles baselines, reboot
  /// resets and gaps (see `StepAggregator`), persists the result and
  /// notifies watchers. Returns the steps credited.
  Future<int> recordCounter(int counter, DateTime at);

  /// User preference: daily step goal, or null when unset.
  Future<int?> dailyGoal();
  Future<void> setDailyGoal(int? goal);

  /// User preference: whether step tracking was turned on.
  Future<bool> isTrackingEnabled();
  Future<void> setTrackingEnabled(bool enabled);

  /// Pushes unsent daily aggregates. Returns the number of days pushed.
  Future<int> syncPending();

  /// Merges Firestore history into local storage (never lowers a local
  /// total). Returns the number of days updated.
  Future<int> pullRemote();
}
