/// What a hint does when tapped.
enum NextUpAction { openTasks, openHabits, openReminders, logWater, logMeal }

class NextUpItem {
  const NextUpItem({
    required this.id,
    required this.text,
    required this.action,
    this.actionLabel,
  });

  /// Stable per kind of hint (not per count), so "dismissed" sticks all day.
  final String id;
  final String text;
  final NextUpAction action;

  /// Short label for one-tap actions ("Log water"); null for navigation.
  final String? actionLabel;
}

class UpcomingReminder {
  const UpcomingReminder({
    required this.id,
    required this.title,
    required this.at,
  });

  final String id;
  final String title;
  final DateTime at;
}

/// A snapshot of today. Nullable fields mean "not known", and the matching
/// hint is simply not shown.
class NextUpInput {
  const NextUpInput({
    required this.now,
    this.tasksOpen = 0,
    this.habitsLeft = 0,
    this.reminders = const [],
    this.pulseKnown = false,
    this.lastWaterAt,
    this.mealsToday = 0,
    this.lastMealAt,
  });

  final DateTime now;
  final int tasksOpen;
  final int habitsLeft;

  /// Reminders still to fire today.
  final List<UpcomingReminder> reminders;

  /// Whether today's Pulse events were loaded. Without them the water and
  /// meal hints stay quiet rather than guess.
  final bool pulseKnown;
  final DateTime? lastWaterAt;
  final int mealsToday;
  final DateTime? lastMealAt;
}

/// Short, calm "what's next" lines from today's data. Deterministic, no
/// model, time-of-day aware, at most [maxItems], and never a hint the user
/// already dismissed or acted on today.
class NextUpEngine {
  const NextUpEngine({this.maxItems = 3});

  final int maxItems;

  List<NextUpItem> compute(
    NextUpInput input, {
    Set<String> suppressed = const {},
  }) {
    final now = input.now;
    final minutes = now.hour * 60 + now.minute;
    final quiet = minutes < 6 * 60 || minutes >= 22 * 60 + 30;
    final ranked = <_Ranked>[];

    // The next reminder today. Soon ones lead; later ones are a gentle note.
    final upcoming =
        input.reminders
            .where((r) => r.at.isAfter(now) && _sameDay(r.at, now))
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    if (upcoming.isNotEmpty) {
      final r = upcoming.first;
      final soon = r.at.difference(now) <= const Duration(hours: 2);
      ranked.add(
        _Ranked(
          soon ? 0 : 4,
          NextUpItem(
            id: 'reminder:${r.id}',
            text: 'Reminder at ${_clock(r.at)}: ${r.title}',
            action: NextUpAction.openReminders,
          ),
        ),
      );
    }

    if (!quiet) {
      final evening = minutes >= 18 * 60;
      final tasks = input.tasksOpen;
      final habits = input.habitsLeft;
      if (tasks > 0 || habits > 0) {
        final parts = <String>[
          if (tasks > 0)
            '$tasks ${tasks == 1 ? 'task' : 'tasks'} '
                '${evening ? 'still open' : 'due today'}',
          if (habits > 0) '$habits ${habits == 1 ? 'habit' : 'habits'} left',
        ];
        final text = parts.join(', ');
        ranked.add(
          _Ranked(
            1,
            NextUpItem(
              id: 'tasks-habits',
              text: text,
              action: tasks > 0
                  ? NextUpAction.openTasks
                  : NextUpAction.openHabits,
            ),
          ),
        );
      }

      if (input.pulseKnown) {
        final awake = minutes >= 9 * 60 && minutes < 21 * 60;
        if (awake) {
          final last = input.lastWaterAt;
          if (last == null && minutes >= 10 * 60) {
            ranked.add(
              const _Ranked(
                2,
                NextUpItem(
                  id: 'water',
                  text: 'No water logged yet today',
                  action: NextUpAction.logWater,
                  actionLabel: 'Log water',
                ),
              ),
            );
          } else if (last != null &&
              now.difference(last) >= const Duration(hours: 3)) {
            ranked.add(
              _Ranked(
                2,
                NextUpItem(
                  id: 'water',
                  text: 'You haven\'t logged water since ${_clock(last)}',
                  action: NextUpAction.logWater,
                  actionLabel: 'Log water',
                ),
              ),
            );
          }
        }
        final mealWindow = minutes >= 13 * 60 + 30 && minutes < 21 * 60;
        if (mealWindow) {
          final last = input.lastMealAt;
          if (input.mealsToday == 0) {
            ranked.add(
              const _Ranked(
                3,
                NextUpItem(
                  id: 'meal',
                  text: 'No meal logged yet today',
                  action: NextUpAction.logMeal,
                  actionLabel: 'Log meal',
                ),
              ),
            );
          } else if (last != null &&
              now.difference(last) >= const Duration(hours: 5)) {
            ranked.add(
              _Ranked(
                3,
                NextUpItem(
                  id: 'meal',
                  text: 'Your last meal was at ${_clock(last)}',
                  action: NextUpAction.logMeal,
                  actionLabel: 'Log meal',
                ),
              ),
            );
          }
        }
      }
    }

    ranked.sort((a, b) => a.priority.compareTo(b.priority));
    return [
      for (final r in ranked)
        if (!suppressed.contains(r.item.id)) r.item,
    ].take(maxItems).toList();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 21:00 -> "9 PM", 9:30 -> "9:30 AM".
  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final suffix = t.hour < 12 ? 'AM' : 'PM';
    return t.minute == 0
        ? '$h $suffix'
        : '$h:${t.minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _Ranked {
  const _Ranked(this.priority, this.item);
  final int priority;
  final NextUpItem item;
}

/// Hints the user dismissed or acted on, for one day. Local only.
abstract class NextUpStore {
  Future<Set<String>> load(String userId, DateTime day);
  Future<void> add(String userId, DateTime day, String id);
}

class InMemoryNextUpStore implements NextUpStore {
  final Map<String, Set<String>> _data = {};

  String _key(String userId, DateTime day) =>
      '$userId|${day.year}-${day.month}-${day.day}';

  @override
  Future<Set<String>> load(String userId, DateTime day) async => {
    ...?_data[_key(userId, day)],
  };

  @override
  Future<void> add(String userId, DateTime day, String id) async {
    _data.putIfAbsent(_key(userId, day), () => {}).add(id);
  }
}
