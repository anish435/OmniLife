// ignore_for_file: prefer_initializing_formals
import '../../repositories/life_event_repository.dart';
import '../../services/pulse/sleep_analyzer.dart';
import '../../services/sleep_source.dart';

/// Reads sleep from OmniPulse: the paired Sleep and Wake taps for the
/// night that ended on the requested day.
class PulseSleepSource implements SleepSource {
  PulseSleepSource(
    this._events, {
    SleepAnalyzer analyzer = const SleepAnalyzer(),
  }) : _analyzer = analyzer;

  final LifeEventRepository _events;
  final SleepAnalyzer _analyzer;

  @override
  Future<double?> sleepHoursFor(String uid, DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    // A night can start the evening before, so look back a day.
    final events = await _events.range(
      uid,
      dayStart.subtract(const Duration(days: 1)),
      dayStart.add(const Duration(days: 1)),
    );
    final nights = _analyzer
        .sessions(events)
        .where((s) => s.wakeDay == dayStart)
        .toList();
    if (nights.isEmpty) return null;
    final minutes = nights.fold<int>(0, (sum, s) => sum + s.duration.inMinutes);
    // One decimal, matching the Wellness slider's half-hour steps.
    return (minutes / 60 * 10).round() / 10;
  }
}
