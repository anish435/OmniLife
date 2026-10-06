import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/services/pulse/daily_facts.dart';

var _seq = 0;

LifeEvent ev(
  LifeEventType type,
  DateTime at, {
  Map<String, dynamic> meta = const {},
  String? id,
}) {
  _seq++;
  return LifeEvent(
    id: id ?? 'e$_seq',
    uid: 'u1',
    type: type,
    timestamp: at,
    createdAt: at,
    updatedAt: at,
    metadata: meta,
  );
}

/// Consecutive [DailyFacts], oldest first, ending on [last].
List<DailyFacts> daysEndingOn(DateTime last, int count) {
  final end = DateTime(last.year, last.month, last.day);
  return [
    for (var i = count - 1; i >= 0; i--)
      DailyFacts(DateTime(end.year, end.month, end.day - i)),
  ];
}
