import 'package:get/get.dart';

import '../../core/services/notification_service.dart';
import '../../domain/assistant/assistant_tool.dart';
import '../../domain/assistant/reminder_time.dart';
import '../../domain/assistant/tool_args.dart';
import '../../domain/assistant/when_format.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/entities/life_event.dart';
import '../../domain/insights/advice_context.dart' show formatMinutes;
import '../../domain/insights/logged_fact.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/task.dart';
import '../controllers/pulse_controller.dart';
import '../controllers/reminders_controller.dart';
import 'assistant_tool_deps.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The default tool set. Every write goes through the same controllers and
/// services the screens use, so lists refresh and data syncs as usual.
List<AssistantTool> buildAssistantTools(AssistantToolDeps deps) => [
  CreateReminderTool(deps),
  CreateTaskTool(deps),
  CompleteTaskTool(deps),
  CreateCalendarEventTool(deps),
  CreateNoteTool(deps),
  AddTransactionTool(deps),
  LogPulseTool(deps),
  ToggleHabitTool(deps),
  ListTasksTodayTool(deps),
  GetSpendingSummaryTool(deps),
  GetSleepSummaryTool(deps),
  GetLifePatternsTool(deps),
  DeleteItemTool(deps),
];

Map<String, dynamic> _schema(
  Map<String, Object> props, {
  List<String> required = const [],
}) => {
  'type': 'object',
  'properties': props,
  if (required.isNotEmpty) 'required': required,
};

const _str = {'type': 'string'};
const _iso = {'type': 'string', 'description': 'ISO-8601 local'};

String _requireUser(AssistantToolDeps deps) {
  final id = deps.userId;
  if (id == null || id.isEmpty) {
    throw const ToolArgException('Please sign in first, then ask me again.');
  }
  return id;
}

/// Finds the one item whose title matches [query]: exact first, then
/// contains. Asks which one when several match.
T _pick<T>(
  Iterable<T> items,
  String query,
  String Function(T) titleOf, {
  required String noun,
}) {
  final q = query.trim().toLowerCase();
  final all = items.toList();
  final exact = all.where((i) => titleOf(i).trim().toLowerCase() == q).toList();
  final matches = exact.isNotEmpty
      ? exact
      : all.where((i) {
          final t = titleOf(i).toLowerCase();
          return t.contains(q) || (q.length > 3 && q.contains(t));
        }).toList();
  if (matches.isEmpty) {
    throw ToolArgException('I couldn\'t find a $noun called "$query".');
  }
  if (matches.length > 1) {
    final names = matches.take(3).map((m) => '"${titleOf(m)}"').join(' or ');
    throw ToolFollowUp('Which $noun do you mean, $names?');
  }
  return matches.first;
}

// ------------------------------------------------------------ reminders

class CreateReminderTool extends AssistantTool {
  const CreateReminderTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'createReminder';
  @override
  String get description => 'Set a reminder (notification) at a time.';
  @override
  Map<String, dynamic> get parameters => _schema(
    {
      'title': _str,
      'at': _iso,
      'repeat': {
        'type': 'string',
        'enum': ['none', 'daily', 'weekly'],
      },
      'note': _str,
    },
  );

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final title = args.string('title') ?? 'Reminder';
    final service = deps.reminders;
    if (service == null) {
      return ToolOutcome.failed('Reminders aren\'t available yet.');
    }
    final argRepeat = switch (args.oneOf('repeat', [
      'none',
      'daily',
      'weekly',
    ])) {
      'daily' => ReminderRepeat.daily,
      'weekly' => ReminderRepeat.weekly,
      _ => ReminderRepeat.none,
    };
    final resolved = ReminderTimeResolver(ctx.now).resolve(
      at: args.when('at', now: ctx.now),
      utterance: ctx.userText,
      argRepeat: argRepeat,
    );
    final reminder = await service.create(
      title: title,
      at: resolved.at,
      repeat: resolved.repeat,
      note: args.string('note', maxLength: 300),
    );
    if (Get.isRegistered<RemindersController>()) {
      Get.find<RemindersController>().load();
    }
    final when = describeWhen(resolved.at, ctx.now);
    final clock = clockTime(resolved.at);
    switch (resolved.repeat) {
      case ReminderRepeat.daily:
        return ToolOutcome.done(
          label: 'Reminder set: $title, every day at $clock',
          spoken: 'I\'ve set a daily reminder for ${spokenClock(resolved.at)}.',
          undo: () async {
            await service.remove(reminder);
            if (Get.isRegistered<RemindersController>()) {
              Get.find<RemindersController>().load();
            }
          },
        );
      case ReminderRepeat.weekly:
        final day = _weekdayNames[resolved.at.weekday - 1];
        return ToolOutcome.done(
          label: 'Reminder set: $title, every $day at $clock',
          spoken:
              'I\'ve set a weekly reminder for $day at ${spokenClock(resolved.at)}.',
          undo: () async {
            await service.remove(reminder);
            if (Get.isRegistered<RemindersController>()) {
              Get.find<RemindersController>().load();
            }
          },
        );
      case ReminderRepeat.none:
        return ToolOutcome.done(
          label: 'Reminder set: $title, $when',
          spoken:
              'I\'ve set a reminder for ${spokenWhen(resolved.at, ctx.now)}.',
          undo: () async {
            await service.remove(reminder);
            if (Get.isRegistered<RemindersController>()) {
              Get.find<RemindersController>().load();
            }
          },
        );
    }
  }
}

// ---------------------------------------------------------------- tasks

class CreateTaskTool extends AssistantTool {
  const CreateTaskTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'createTask';
  @override
  String get description => 'Add a to-do task.';
  @override
  Map<String, dynamic> get parameters => _schema(
    {
      'title': _str,
      'due': _iso,
      'priority': {
        'type': 'string',
        'enum': ['low', 'medium', 'high'],
      },
    },
    required: ['title'],
  );

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final title = args.string('title', required: true)!;
    final due = args.when('due', now: ctx.now);
    final priority = switch (args.oneOf('priority', [
      'low',
      'medium',
      'high',
    ])) {
      'low' => TaskPriority.low,
      'high' => TaskPriority.high,
      _ => TaskPriority.medium,
    };
    final tasks = deps.tasks;
    final created = await tasks.createTask(
      title: title,
      dueDate: due?.value,
      priority: priority,
    );
    if (created == null) {
      return ToolOutcome.failed('I couldn\'t add that task. Please try again.');
    }

    Reminder? linkedReminder;
    final reminders = deps.reminders;
    if (due != null) {
      if (Get.isRegistered<NotificationService>()) {
        final notifService = Get.find<NotificationService>();
        await notifService.scheduleReminder(
          id: created.title.hashCode & 0x7FFFFFFF,
          title: 'Task Reminder: ${created.title}',
          body: 'Task is due now',
          scheduledDate: due.value,
          payload: 'task:${created.id}',
          alarmClock: true,
        );
      }
      if (reminders != null) {
        try {
          linkedReminder = await reminders.create(
            title: created.title,
            at: due.value,
            repeat: ReminderRepeat.none,
            note:
                'Task due ${due.hasTime ? describeWhen(due.value, ctx.now) : dayWord(due.value, ctx.now)}',
          );
          if (Get.isRegistered<RemindersController>()) {
            Get.find<RemindersController>().load();
          }
        } catch (_) {}
      }
    }

    final dueText = due == null
        ? ''
        : ', due ${due.hasTime ? describeWhen(due.value, ctx.now) : dayWord(due.value, ctx.now)}';
    return ToolOutcome.done(
      label: 'Task added: ${created.title}$dueText',
      spoken: 'I\'ve added "${created.title}" to your tasks.',
      undo: () async {
        await tasks.deleteTask(created.id);
        if (linkedReminder != null && reminders != null) {
          try {
            await reminders.remove(linkedReminder);
            if (Get.isRegistered<RemindersController>()) {
              Get.find<RemindersController>().load();
            }
          } catch (_) {}
        }
        if (Get.isRegistered<NotificationService>()) {
          await Get.find<NotificationService>().cancelReminder(
            created.title.hashCode & 0x7FFFFFFF,
          );
        }
      },
    );
  }
}

class CompleteTaskTool extends AssistantTool {
  const CompleteTaskTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'completeTask';
  @override
  String get description => 'Mark an open task as done, found by its title.';
  @override
  Map<String, dynamic> get parameters =>
      _schema({'title': _str}, required: ['title']);

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final query = args.string('title', required: true)!;
    final tasks = deps.tasks;
    final task = _pick<Task>(
      tasks.tasks.where((t) => !t.completed),
      query,
      (t) => t.title,
      noun: 'task',
    );
    await tasks.toggleTask(task.id);
    final now = tasks.tasks.where((t) => t.id == task.id).firstOrNull;
    if (now == null || !now.completed) {
      return ToolOutcome.failed('I couldn\'t mark that one done. Try again?');
    }
    return ToolOutcome.done(
      label: 'Task done: ${task.title}',
      spoken: 'I\'ve marked "${task.title}" as done.',
      undo: () => tasks.toggleTask(task.id),
    );
  }
}

class ListTasksTodayTool extends AssistantTool {
  const ListTasksTodayTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'listTasksToday';
  @override
  String get description => 'Read out today\'s open tasks.';
  @override
  Map<String, dynamic> get parameters => _schema({});

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final open = deps.tasks.todayTasks.where((t) => !t.completed).toList();
    if (open.isEmpty) {
      return ToolOutcome.info('You have nothing left to do today.');
    }
    final names = open.take(5).map((t) => t.title).join(', ');
    final more = open.length > 5 ? ' and ${open.length - 5} more' : '';
    final n = open.length;
    return ToolOutcome.info(
      'You have $n ${n == 1 ? 'task' : 'tasks'} today: $names$more.',
    );
  }
}

// ------------------------------------------------------------- calendar

class CreateCalendarEventTool extends AssistantTool {
  const CreateCalendarEventTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'createCalendarEvent';
  @override
  String get description => 'Add a calendar event.';
  @override
  Map<String, dynamic> get parameters => _schema(
    {
      'title': _str,
      'start': _iso,
      'end': _iso,
      'minutes': {'type': 'integer', 'description': 'duration, default 60'},
    },
    required: ['title', 'start'],
  );

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final title = args.string('title', required: true)!;
    final start = args.when('start', now: ctx.now);
    if (start == null || !start.hasTime) {
      throw const ToolFollowUp('What time should the event start?');
    }
    final endArg = args.when('end', now: ctx.now);
    final minutes = args.number('minutes', min: 5, max: 1440);
    final end = endArg != null && endArg.hasTime
        ? endArg.value
        : start.value.add(Duration(minutes: (minutes ?? 60).round()));
    if (!end.isAfter(start.value)) {
      return ToolOutcome.failed('The end needs to be after the start.');
    }
    final calendar = deps.calendar;
    final created = await calendar.createEvent(
      title: title,
      startAt: start.value,
      endAt: end,
    );
    if (created == null) {
      return ToolOutcome.failed(
        'I couldn\'t add that event. Please try again.',
      );
    }
    return ToolOutcome.done(
      label: 'Event added: $title, ${describeWhen(start.value, ctx.now)}',
      spoken: 'I\'ve added "$title" for ${spokenWhen(start.value, ctx.now)}.',
      undo: () async {
        await calendar.deleteEvent(created.id);
      },
    );
  }
}

// ---------------------------------------------------------------- notes

class CreateNoteTool extends AssistantTool {
  const CreateNoteTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'createNote';
  @override
  String get description => 'Save a note.';
  @override
  Map<String, dynamic> get parameters =>
      _schema({'title': _str, 'content': _str}, required: ['content']);

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final content = args.string('content', maxLength: 4000, required: true)!;
    var title = args.string('title') ?? content;
    if (title.length > 60) title = '${title.substring(0, 57).trimRight()}...';
    final notes = deps.notes;
    final created = await notes.createNote(title, content);
    if (created == null) {
      return ToolOutcome.failed(
        'I couldn\'t save that note. Please try again.',
      );
    }
    return ToolOutcome.done(
      label: 'Note saved: $title',
      spoken: 'I\'ve saved that as a note.',
      undo: () async {
        await notes.deleteNote(created.id);
      },
    );
  }
}

// -------------------------------------------------------------- finance

class AddTransactionTool extends AssistantTool {
  const AddTransactionTool(this.deps);
  final AssistantToolDeps deps;

  static final _incomeWords = RegExp(
    r'\b(received|earned|salary|income|bonus|paid me|got paid|refund(ed)?)\b',
    caseSensitive: false,
  );

  @override
  String get name => 'addTransaction';
  @override
  String get description =>
      'Record money spent (expense) or received (income). Amount is positive.';
  @override
  Map<String, dynamic> get parameters => _schema(
    {
      'amount': {'type': 'number'},
      'title': _str,
      'category': {
        'type': 'string',
        'enum': [
          'food',
          'transport',
          'utilities',
          'entertainment',
          'shopping',
          'health',
          'other',
        ],
      },
      'income': {
        'type': 'boolean',
        'description': 'true for money received/income, false for spent/expense',
      },
      'date': _iso,
      'entries': {
        'type': 'array',
        'description':
            'When multiple transactions are given, list each with amount, title, income, category',
        'items': {
          'type': 'object',
          'properties': {
            'amount': {'type': 'number'},
            'title': {'type': 'string'},
            'income': {'type': 'boolean'},
            'category': {'type': 'string'},
          },
          'required': ['amount'],
        },
      },
    },
  );

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final rawEntries = args.raw['entries'];
    if (rawEntries is List && rawEntries.isNotEmpty) {
      final finance = deps.finance;
      final results = <FinanceTransaction>[];
      for (final e in rawEntries) {
        if (e is Map) {
          final amt = (e['amount'] as num?)?.toDouble();
          if (amt == null || amt <= 0) continue;
          final inc = e['income'] == true;
          final t = (e['title'] as String?) ?? (inc ? 'Income' : 'Expense');
          final cat = inc
              ? TransactionCategory.income
              : TransactionCategory.values.firstWhere(
                  (c) =>
                      c != TransactionCategory.income &&
                      c.name == e['category']?.toString().toLowerCase(),
                  orElse: () => TransactionCategory.other,
                );
          final created = await finance.addTransaction(
            amount: amt,
            title: t,
            category: cat,
            date: ctx.now,
            isIncome: inc,
          );
          if (created != null) results.add(created);
        }
      }
      if (results.isNotEmpty) {
        final totalInc = results
            .where((t) => t.isIncome)
            .fold<double>(0, (s, t) => s + t.amount);
        final totalExp = results
            .where((t) => !t.isIncome)
            .fold<double>(0, (s, t) => s + t.amount);
        final parts = <String>[];
        if (totalInc > 0) parts.add('Income ${formatAmount(totalInc)}');
        if (totalExp > 0) parts.add('Expense ${formatAmount(totalExp)}');
        final net = totalInc - totalExp;
        return ToolOutcome.done(
          label:
              'Logged: ${parts.join(', ')} (Net: ${net >= 0 ? '+' : ''}${formatAmount(net)})',
          spoken: 'I\'ve recorded ${parts.join(' and ')}.',
          undo: () async {
            for (final r in results) {
              await finance.deleteTransaction(r.id);
            }
          },
        );
      }
    }

    if (!args.has('amount')) throw const ToolFollowUp('How much was it?');
    final amount = args.number('amount', min: 0.01, max: 100000000)!;
    final title = args.string('title') ?? 'Transaction';
    final bool income;
    if (args.boolean('income') != null) {
      income = args.boolean('income')!;
    } else if (title.isNotEmpty && _incomeWords.hasMatch(title)) {
      income = true;
    } else {
      income = _incomeWords.hasMatch(ctx.userText);
    }
    final category = income
        ? TransactionCategory.income
        : TransactionCategory.values.firstWhere(
            (c) =>
                c != TransactionCategory.income &&
                c.name == args.string('category')?.toLowerCase(),
            orElse: () => TransactionCategory.other,
          );

    final given = args.when('date', now: ctx.now);
    var date = ctx.now;
    if (given != null) {
      final d = given.value;
      final isToday =
          d.year == ctx.now.year &&
          d.month == ctx.now.month &&
          d.day == ctx.now.day;
      date = isToday ? ctx.now : d;
    }

    final finance = deps.finance;
    final created = await finance.addTransaction(
      amount: amount,
      title: title,
      category: category,
      date: date,
      isIncome: income,
    );
    if (created == null) {
      return ToolOutcome.failed(
        'I couldn\'t record that. Please check you\'re signed in and try again.',
      );
    }
    final shown = formatAmount(amount);
    return ToolOutcome.done(
      label: '${income ? 'Income' : 'Expense'} added: $shown, $title',
      spoken: income
          ? 'I\'ve recorded $shown as income.'
          : 'I\'ve recorded a $shown expense.',
      undo: () async {
        await finance.deleteTransaction(created.id);
      },
    );
  }
}

class GetSpendingSummaryTool extends AssistantTool {
  const GetSpendingSummaryTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'getSpendingSummary';
  @override
  String get description => 'Summarise spending for a period.';
  @override
  Map<String, dynamic> get parameters => _schema({
    'period': {
      'type': 'string',
      'enum': ['today', 'week', 'month'],
    },
  });

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final uid = _requireUser(deps);
    final period = args.oneOf('period', ['today', 'week', 'month']) ?? 'month';
    final now = ctx.now;
    final today = DateTime(now.year, now.month, now.day);
    final from = switch (period) {
      'today' => today,
      'week' => today.subtract(const Duration(days: 6)),
      _ => DateTime(now.year, now.month, 1),
    };
    final months = {(from.year, from.month), (now.year, now.month)};
    final all = <FinanceTransaction>[];
    for (final (y, m) in months) {
      all.addAll(
        await deps.financeRepository.getTransactions(uid, month: m, year: y),
      );
    }
    final spent = all
        .where((t) => !t.isIncome && !t.date.isBefore(from))
        .toList();
    final label = switch (period) {
      'today' => 'today',
      'week' => 'in the last 7 days',
      _ => 'this month',
    };
    if (spent.isEmpty) {
      return ToolOutcome.info('I don\'t see any spending logged $label.');
    }
    final total = spent.fold<double>(0, (s, t) => s + t.amount);
    final byCat = <TransactionCategory, double>{};
    for (final t in spent) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final top = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topText = top
        .take(2)
        .map((e) => '${e.key.name} (${formatAmount(e.value)})')
        .join(' and ');
    return ToolOutcome.info(
      'You\'ve spent ${formatAmount(total)} $label, mostly on $topText.',
    );
  }
}

// ---------------------------------------------------------------- pulse

class LogPulseTool extends AssistantTool {
  const LogPulseTool(this.deps);
  final AssistantToolDeps deps;

  static const kinds = [
    'sleep',
    'wake',
    'water',
    'meal',
    'workout',
    'focus',
    'mood',
    'energy',
    'note',
  ];

  static const periods = ['now', 'morning', 'afternoon', 'evening'];

  /// Used when the user says "this morning" without a time.
  static const morningHour = 8;
  static const defaultWakeHour = 7;

  @override
  String get name => 'logPulse';
  @override
  String get description =>
      'Quick-log moments: going to sleep, waking, or a night already slept '
      '(hours), water (ml), meal, workout or focus (minutes), mood or energy '
      '(value 1-5), or a note (text). When the user mentions several things, '
      'put ALL of them in entries in this single call. Use period/at to '
      'backdate.';
  @override
  Map<String, dynamic> get parameters => _schema(
    {
      'entries': {'type': 'array', 'items': entrySchema},
    },
    required: ['entries'],
  );

  /// One logged fact. The model lists every fact in `entries`; the engine
  /// splits them into one call each (see [expandEntries]).
  static const entrySchema = {
    'type': 'object',
    'properties': {
      'kind': {'type': 'string', 'enum': kinds},
      'value': {
        'type': 'number',
        'description': 'ml of water, 1-5 for mood/energy, or minutes',
      },
      'hours': {
        'type': 'number',
        'description': 'sleep: how long they slept, in hours',
      },
      'ml': {'type': 'number', 'description': 'water in ml (2 L = 2000)'},
      'minutes': {'type': 'number', 'description': 'workout or focus length'},
      'period': {
        'type': 'string',
        'enum': periods,
        'description': 'when it happened, if not just now',
      },
      'at': {
        'type': 'string',
        'description': 'ISO-8601 local time it happened (sleep: wake time)',
      },
      'text': {'type': 'string'},
    },
    'required': ['kind'],
  };

  /// When the moment happened, or null for "now". An explicit `at` wins;
  /// otherwise `period` picks a sensible hour, never later than now.
  DateTime? _momentAt(ToolArgs args, DateTime now) {
    final when = args.when('at', now: now);
    if (when != null) {
      if (when.value.isAfter(now.add(const Duration(minutes: 5)))) {
        throw const ToolArgException('That time is still ahead of us.');
      }
      return when.value;
    }
    final period = args.oneOf('period', periods);
    final hour = switch (period) {
      'morning' => morningHour,
      'afternoon' => 14,
      'evening' => 18,
      _ => null,
    };
    if (hour == null) return null;
    final t = DateTime(now.year, now.month, now.day, hour);
    return t.isAfter(now) ? now : t;
  }

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final kind = args.oneOf('kind', kinds);
    if (kind == null) throw const ToolFollowUp('What would you like to log?');
    _requireUser(deps);
    final text = args.string('text', maxLength: 300);
    final pulse = deps.pulse;
    final now = ctx.now;

    switch (kind) {
      case 'sleep':
        final hours = args.number('hours', min: 0.5, max: 16);
        if (hours != null) return _sleepSession(args, pulse, now, hours);
        final r = await pulse.startSleep();
        if (r == null) return _failed();
        if (r.alreadyAsleep) {
          return ToolOutcome.info('You\'re already logged as asleep.');
        }
        return _done(
          'Logged: going to sleep',
          'I\'ve logged that you\'re going to sleep.',
          pulse,
          r.event,
        );
      case 'wake':
        final r = await pulse.wake();
        if (r == null) return _failed();
        final d = r.sleepDuration;
        final slept = d == null
            ? ''
            : ' You slept ${d.inHours}h ${d.inMinutes % 60}m.';
        return _done(
          'Logged: woke up',
          'I\'ve logged that you woke up.$slept',
          pulse,
          r.event,
          fact: d == null
              ? null
              : LoggedFact(LoggedKind.sleep, value: d.inMinutes, at: now),
        );
      case 'water':
        final liters = args.number('liters', min: 0.03, max: 5);
        final ml =
            args.number('ml', min: 30, max: 5000) ??
            (liters == null ? null : liters * 1000) ??
            args.number('value', min: 30, max: 5000);
        final at = _momentAt(args, now);
        final r = await pulse.log(
          LifeEventType.water,
          metadata: {'ml': ?ml?.round()},
          at: at,
        );
        if (r == null) return _failed();
        return _done(
          'Logged: water${ml == null ? '' : ' ${ml.round()} ml'}',
          'I\'ve logged some water.',
          pulse,
          r.event,
          fact: LoggedFact(
            LoggedKind.water,
            value: (ml ?? 250).round(),
            at: at ?? now,
          ),
        );
      case 'meal':
        final at = _momentAt(args, now);
        final r = await pulse.log(
          LifeEventType.meal,
          metadata: {'label': ?text},
          at: at,
        );
        if (r == null) return _failed();
        return _done(
          'Logged: meal${text == null ? '' : ', $text'}',
          'I\'ve logged your meal.',
          pulse,
          r.event,
          fact: LoggedFact(LoggedKind.meal, at: at ?? now),
        );
      case 'workout':
        final mins = _minutes(args);
        final at = _momentAt(args, now);
        final r = await pulse.log(
          LifeEventType.workout,
          metadata: {'label': ?text, 'minutes': ?mins},
          at: at,
        );
        if (r == null) return _failed();
        return _done(
          'Logged: workout${mins == null ? '' : ' $mins min'}'
              '${text == null ? '' : ', $text'}',
          'I\'ve logged your workout.',
          pulse,
          r.event,
          fact: LoggedFact(LoggedKind.workout, value: mins, at: at ?? now),
        );
      case 'focus':
        final mins = _minutes(args);
        if (mins == null) {
          throw const ToolFollowUp('How many minutes did you focus for?');
        }
        final at = _momentAt(args, now);
        final r = await pulse.log(
          LifeEventType.focus,
          metadata: {'label': ?text, 'minutes': mins},
          at: at,
        );
        if (r == null) return _failed();
        return _done(
          'Logged: focus $mins min',
          'I\'ve logged $mins minutes of focus.',
          pulse,
          r.event,
          fact: LoggedFact(LoggedKind.focus, value: mins, at: at ?? now),
        );
      case 'mood':
      case 'energy':
        if (!args.has('value')) {
          throw ToolFollowUp('How is your $kind, from 1 to 5?');
        }
        final v = args.number('value', min: 1, max: 5)!.round();
        final isMood = kind == 'mood';
        final at = _momentAt(args, now);
        final r = await pulse.log(
          isMood ? LifeEventType.mood : LifeEventType.energy,
          metadata: {isMood ? 'score' : 'level': v},
          at: at,
        );
        if (r == null) return _failed();
        return _done(
          'Logged: $kind $v/5',
          'I\'ve logged your $kind as $v out of 5.',
          pulse,
          r.event,
          fact: LoggedFact(
            isMood ? LoggedKind.mood : LoggedKind.energy,
            value: v,
            at: at ?? now,
          ),
        );
      default:
        if (text == null) throw const ToolFollowUp('What should the note say?');
        final r = await pulse.log(
          LifeEventType.note,
          metadata: {'label': text},
        );
        if (r == null) return _failed();
        return _done(
          'Logged: note, $text',
          'I\'ve added that to your day.',
          pulse,
          r.event,
        );
    }
  }

  int? _minutes(ToolArgs args) =>
      (args.number('minutes', min: 1, max: 720) ??
              args.number('value', min: 1, max: 720))
          ?.round();

  /// "I slept 3 hours": a completed night ending at the stated wake time,
  /// or 7 AM today when none was given (never in the future).
  Future<ToolOutcome> _sleepSession(
    ToolArgs args,
    PulseController pulse,
    DateTime now,
    double hours,
  ) async {
    final minutes = (hours * 60).round();
    final stated = _momentAt(args, now);
    var wake =
        stated ?? DateTime(now.year, now.month, now.day, defaultWakeHour);
    if (wake.isAfter(now)) wake = now;
    final r = await pulse.logSleepSession(
      duration: Duration(minutes: minutes),
      wakeAt: wake,
    );
    if (r == null) return _failed();
    final label = formatMinutes(minutes);
    final all = [r.event, ...r.extraEvents];
    return ToolOutcome.done(
      label: 'Logged: slept $label',
      spoken: 'I\'ve logged $label of sleep.',
      undo: () async {
        for (final e in all) {
          await pulse.undo(e);
        }
      },
      fact: LoggedFact(LoggedKind.sleep, value: minutes, at: wake),
    );
  }

  ToolOutcome _failed() =>
      ToolOutcome.failed('That didn\'t save. Please try again.');

  ToolOutcome _done(
    String label,
    String spoken,
    PulseController pulse,
    LifeEvent e, {
    LoggedFact? fact,
  }) => ToolOutcome.done(
    label: label,
    spoken: spoken,
    undo: () async {
      await pulse.undo(e);
    },
    fact: fact,
  );
}

class GetSleepSummaryTool extends AssistantTool {
  const GetSleepSummaryTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'getSleepSummary';
  @override
  String get description => 'Summarise the user\'s logged sleep.';
  @override
  Map<String, dynamic> get parameters => _schema({});

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final uid = _requireUser(deps);
    final insights = await deps.insights.load(uid, days: 30);
    final s = insights.sleep;
    final avg = s.averageDuration;
    if (s.nights == 0 || avg == null) {
      return ToolOutcome.info(
        'I don\'t have any sleep logged yet. Tap Sleep and Wake on the Pulse screen and I\'ll pick it up.',
      );
    }
    final bed = s.averageBedtime;
    final bedText = bed == null
        ? ''
        : ', usually going to bed around ${clockTime(DateTime(2000, 1, 1, bed ~/ 60, bed % 60))}';
    final n = s.nights;
    return ToolOutcome.info(
      'Over your last $n ${n == 1 ? 'night' : 'nights'} you\'ve averaged '
      '${avg.inHours}h ${avg.inMinutes % 60}m of logged sleep$bedText.',
    );
  }
}

class GetLifePatternsTool extends AssistantTool {
  const GetLifePatternsTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'getLifePatterns';
  @override
  String get description => 'Share patterns found in the user\'s own data.';
  @override
  Map<String, dynamic> get parameters => _schema({});

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final uid = _requireUser(deps);
    final insights = await deps.insights.load(uid);
    if (insights.patterns.isEmpty) {
      return ToolOutcome.info(
        'I don\'t see a clear pattern yet. A few more days of logging will help.',
      );
    }
    final lines = insights.patterns.take(2).map((p) => p.statement).join(' ');
    return ToolOutcome.info(
      '$lines These are links in your own data, not proof that one causes the other.',
    );
  }
}

// --------------------------------------------------------------- habits

class ToggleHabitTool extends AssistantTool {
  const ToggleHabitTool(this.deps);
  final AssistantToolDeps deps;

  @override
  String get name => 'toggleHabit';
  @override
  String get description => 'Mark a habit done for today, found by name.';
  @override
  Map<String, dynamic> get parameters =>
      _schema({'name': _str}, required: ['name']);

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext ctx) async {
    final query = args.string('name', required: true)!;
    final habits = deps.habits;
    final habit = _pick(habits.habits, query, (h) => h.title, noun: 'habit');
    final today = habits.today;
    if (habits.isHabitCompleted(habit.id, today)) {
      return ToolOutcome.info('"${habit.title}" is already done for today.');
    }
    final result = await habits.toggleHabitLog(habit.id, today);
    if (result != true) {
      return ToolOutcome.failed('I couldn\'t update that habit. Try again?');
    }
    return ToolOutcome.done(
      label: 'Habit done: ${habit.title}',
      spoken: 'I\'ve ticked off "${habit.title}" for today.',
      undo: () async {
        await habits.toggleHabitLog(habit.id, today);
      },
    );
  }
}

// --------------------------------------------------------------- delete

class DeleteItemTool extends DestructiveTool {
  const DeleteItemTool(this.deps);
  final AssistantToolDeps deps;

  static const kinds = ['task', 'note', 'reminder', 'event'];

  @override
  String get name => 'deleteItem';
  @override
  String get description =>
      'Delete a task, note, reminder or event by title. Always asks first.';
  @override
  Map<String, dynamic> get parameters => _schema(
    {
      'kind': {'type': 'string', 'enum': kinds},
      'title': _str,
    },
    required: ['kind', 'title'],
  );

  @override
  Future<DestructivePlan> plan(ToolArgs args, ToolContext ctx) async {
    final kind = args.oneOf('kind', kinds);
    if (kind == null) {
      throw const ToolFollowUp('What would you like me to delete?');
    }
    final query = args.string('title', required: true)!;

    switch (kind) {
      case 'task':
        final tasks = deps.tasks;
        final t = _pick<Task>(tasks.tasks, query, (x) => x.title, noun: 'task');
        return _plan('task', t.title, () async {
          await tasks.deleteTask(t.id);
        });
      case 'note':
        final notes = deps.notes;
        final n = _pick(notes.notes, query, (x) => x.title, noun: 'note');
        return _plan('note', n.title, () async {
          await notes.deleteNote(n.id);
        });
      case 'event':
        final cal = deps.calendar;
        final e = _pick(cal.events, query, (x) => x.title, noun: 'event');
        return _plan('event', e.title, () async {
          await cal.deleteEvent(e.id);
        });
      default:
        final service = deps.reminders;
        if (service == null) {
          throw const ToolArgException('Reminders aren\'t available yet.');
        }
        final r = _pick(
          await service.all(),
          query,
          (x) => x.title,
          noun: 'reminder',
        );
        return _plan('reminder', r.title, () => service.remove(r));
    }
  }

  DestructivePlan _plan(
    String noun,
    String title,
    Future<void> Function() action,
  ) => DestructivePlan(
    label: 'Delete $noun: $title',
    question: 'Delete the $noun "$title"? This can\'t be undone.',
    perform: () async {
      await action();
      return ToolOutcome.done(
        label: 'Deleted $noun: $title',
        spoken: 'I\'ve deleted "$title".',
      );
    },
  );
}
