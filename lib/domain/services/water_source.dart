/// Where Wellness reads and changes a day's water intake. Pulse water
/// events are the single record, so Wellness and Pulse always agree.
abstract class WaterSource {
  /// Total millilitres logged on [day] (0 when nothing was logged).
  Future<int> totalMlFor(String uid, DateTime day);

  /// Logs [ml] of water on [day].
  Future<void> add(String uid, DateTime day, int ml);

  /// Takes back up to [ml] from [day], newest drink first.
  Future<void> remove(String uid, DateTime day, int ml);
}
