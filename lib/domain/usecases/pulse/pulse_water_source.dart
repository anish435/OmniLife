import '../../entities/life_event.dart';
import '../../repositories/life_event_repository.dart';
import '../../services/water_source.dart';

/// Reads and writes water through OmniPulse water events.
class PulseWaterSource implements WaterSource {
  PulseWaterSource(this._events, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LifeEventRepository _events;
  final DateTime Function() _now;

  static const _defaultMl = 250;

  int _mlOf(LifeEvent e) => (e.metadata['ml'] as num?)?.toInt() ?? _defaultMl;

  Future<List<LifeEvent>> _waterOn(String uid, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final events = await _events.range(
      uid,
      start,
      start.add(const Duration(days: 1)),
    );
    return events.where((e) => e.type == LifeEventType.water).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<int> totalMlFor(String uid, DateTime day) async {
    final water = await _waterOn(uid, day);
    return water.fold<int>(0, (sum, e) => sum + _mlOf(e));
  }

  @override
  Future<void> add(String uid, DateTime day, int ml) async {
    final now = _now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final at = isToday ? now : DateTime(day.year, day.month, day.day, 12);
    await _events.record(
      uid,
      LifeEventType.water,
      at: at,
      metadata: {'ml': ml},
    );
  }

  @override
  Future<void> remove(String uid, DateTime day, int ml) async {
    var left = ml;
    final water = (await _waterOn(uid, day)).reversed.toList();
    for (final e in water) {
      if (left <= 0) break;
      final have = _mlOf(e);
      if (have <= left) {
        await _events.delete(e);
        left -= have;
      } else {
        await _events.update(
          e.copyWith(metadata: {...e.metadata, 'ml': have - left}),
        );
        left = 0;
      }
    }
  }
}
