import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/insights/next_up.dart';

DateTime _at(int h, [int m = 0]) => DateTime(2026, 10, 19, h, m);

List<String> _texts(List<NextUpItem> items) => [for (final i in items) i.text];

void main() {
  const engine = NextUpEngine();

  test('combines tasks and habits into one calm line', () {
    final items = engine.compute(
      NextUpInput(now: _at(11), tasksOpen: 2, habitsLeft: 1),
    );
    expect(_texts(items), ['2 tasks due today, 1 habit left']);
    expect(items.single.action, NextUpAction.openTasks);
  });

  test('singular wording and habits-only action', () {
    final items = engine.compute(NextUpInput(now: _at(11), habitsLeft: 1));
    expect(_texts(items), ['1 habit left']);
    expect(items.single.action, NextUpAction.openHabits);
    final one = engine.compute(NextUpInput(now: _at(11), tasksOpen: 1));
    expect(_texts(one), ['1 task due today']);
  });

  test('evening wording changes with the time of day', () {
    final items = engine.compute(
      NextUpInput(now: _at(19), tasksOpen: 2, habitsLeft: 2),
    );
    expect(_texts(items), ['2 tasks still open, 2 habits left']);
  });

  test('water gap names the last time, or says none yet', () {
    final since = engine.compute(
      NextUpInput(now: _at(13), pulseKnown: true, lastWaterAt: _at(9)),
    );
    expect(_texts(since), ['You haven\'t logged water since 9 AM']);
    expect(since.single.action, NextUpAction.logWater);
    expect(since.single.actionLabel, 'Log water');

    final none = engine.compute(NextUpInput(now: _at(11), pulseKnown: true));
    expect(_texts(none), ['No water logged yet today']);

    // Recent water, or too early to say anything.
    expect(
      engine.compute(
        NextUpInput(now: _at(11), pulseKnown: true, lastWaterAt: _at(10)),
      ),
      isEmpty,
    );
    expect(
      engine.compute(NextUpInput(now: _at(9, 30), pulseKnown: true)),
      isEmpty,
    );
  });

  test('without loaded Pulse data it does not guess about water or meals', () {
    expect(engine.compute(NextUpInput(now: _at(15))), isEmpty);
  });

  test('meal hints wait until the afternoon', () {
    expect(
      _texts(
        engine.compute(
          NextUpInput(now: _at(12), pulseKnown: true, lastWaterAt: _at(11)),
        ),
      ),
      isEmpty,
    );
    expect(
      _texts(
        engine.compute(
          NextUpInput(now: _at(14), pulseKnown: true, lastWaterAt: _at(13)),
        ),
      ),
      ['No meal logged yet today'],
    );
    expect(
      _texts(
        engine.compute(
          NextUpInput(
            now: _at(15),
            pulseKnown: true,
            lastWaterAt: _at(14),
            mealsToday: 1,
            lastMealAt: _at(9, 30),
          ),
        ),
      ),
      ['Your last meal was at 9:30 AM'],
    );
  });

  test('reminders: the next one today, soon ones first', () {
    final r = [
      UpcomingReminder(id: 'a', title: 'Take tablets', at: _at(21)),
      UpcomingReminder(id: 'b', title: 'Later one', at: _at(22)),
      UpcomingReminder(
        id: 'c',
        title: 'Tomorrow',
        at: _at(9).add(const Duration(days: 1)),
      ),
      UpcomingReminder(id: 'd', title: 'Passed', at: _at(8)),
    ];
    final items = engine.compute(
      NextUpInput(now: _at(20), reminders: r, tasksOpen: 1),
    );
    expect(_texts(items), [
      'Reminder at 9 PM: Take tablets',
      '1 task still open',
    ]);
    // Far-off reminders sit below the to-dos.
    final early = engine.compute(
      NextUpInput(now: _at(10), reminders: r, tasksOpen: 1),
    );
    expect(_texts(early), [
      '1 task due today',
      'Reminder at 9 PM: Take tablets',
    ]);
  });

  test('shows at most three, in priority order', () {
    final items = engine.compute(
      NextUpInput(
        now: _at(15),
        tasksOpen: 3,
        habitsLeft: 2,
        pulseKnown: true,
        lastWaterAt: _at(9),
        reminders: [UpcomingReminder(id: 'a', title: 'Call', at: _at(16))],
      ),
    );
    expect(items, hasLength(3));
    expect(items.first.id, 'reminder:a');
    expect(items.map((i) => i.id), isNot(contains('meal')));
  });

  test('hides itself when nothing is useful, and at night', () {
    expect(engine.compute(NextUpInput(now: _at(12))), isEmpty);
    // Quiet hours: only a reminder would show.
    expect(
      engine.compute(
        NextUpInput(
          now: _at(23),
          tasksOpen: 2,
          habitsLeft: 2,
          pulseKnown: true,
        ),
      ),
      isEmpty,
    );
    expect(
      engine.compute(NextUpInput(now: _at(5), tasksOpen: 2, habitsLeft: 2)),
      isEmpty,
    );
  });

  test('dismissed or acted-on hints are not shown again', () {
    final input = NextUpInput(
      now: _at(15),
      tasksOpen: 1,
      pulseKnown: true,
      lastWaterAt: _at(9),
    );
    expect(engine.compute(input).map((i) => i.id), [
      'tasks-habits',
      'water',
      'meal',
    ]);
    expect(engine.compute(input, suppressed: {'water'}).map((i) => i.id), [
      'tasks-habits',
      'meal',
    ]);
    // The id is per kind of hint, so a changed count does not bring it back.
    final more = NextUpInput(now: _at(15), tasksOpen: 4);
    expect(engine.compute(more, suppressed: {'tasks-habits'}), isEmpty);
  });

  test('store keeps dismissals per user and per day', () async {
    final store = InMemoryNextUpStore();
    await store.add('u1', _at(10), 'water');
    expect(await store.load('u1', _at(18)), {'water'});
    expect(
      await store.load('u1', _at(10).add(const Duration(days: 1))),
      isEmpty,
    );
    expect(await store.load('u2', _at(10)), isEmpty);
  });
}
