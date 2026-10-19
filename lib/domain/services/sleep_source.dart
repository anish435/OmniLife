/// Where Wellness can look up how long someone slept on a given day when
/// they have not typed it in themselves.
abstract class SleepSource {
  /// Hours slept in the night that ended on [day] (attributed to the day
  /// the person woke up), or null when nothing was recorded.
  Future<double?> sleepHoursFor(String uid, DateTime day);
}

/// A source that never knows anything. Used when sleep tracking is absent.
class NoSleepSource implements SleepSource {
  const NoSleepSource();

  @override
  Future<double?> sleepHoursFor(String uid, DateTime day) async => null;
}
