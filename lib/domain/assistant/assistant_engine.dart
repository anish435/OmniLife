// ignore_for_file: prefer_initializing_formals

import '../insights/linked_advisor.dart';
import 'ai_provider.dart';
import 'assistant_tool.dart';
import 'when_format.dart';

/// Everything that came out of one user command.
class AssistantTurn {
  const AssistantTurn({
    required this.reply,
    this.outcomes = const [],
    this.failure,
  });

  /// What to show and (optionally) speak.
  final String reply;

  /// Tool results in order. Cards are built from these.
  final List<ToolOutcome> outcomes;

  /// Set when the model could not be reached; [reply] is then the friendly
  /// explanation.
  final AiFailureKind? failure;
}

/// Runs one user command: a single model request that may ask for tools,
/// the tools themselves, and a locally written confirmation.
///
/// Free-tier friendly by design: one request per command (plus the
/// provider's single retry on throttling), a compact prompt, and only the
/// last few turns of history. The confirmation text is generated here from
/// the tool results rather than by a second model round.
class AssistantEngine {
  AssistantEngine({
    required AiProvider provider,
    required ToolRegistry tools,
    DateTime Function()? now,
    this.maxHistoryMessages = 12,
    this.maxToolCalls = 8,
    LinkedAdvisor? Function()? advisor,
  }) : _provider = provider,
       _tools = tools,
       _advisor = advisor,
       _now = now ?? DateTime.now;

  final AiProvider _provider;
  final ToolRegistry _tools;
  final DateTime Function() _now;
  final LinkedAdvisor? Function()? _advisor;
  final int maxHistoryMessages;
  final int maxToolCalls;

  bool get isConfigured => _provider.isConfigured;

  Future<AssistantTurn> handle(
    String userText, {
    List<AiMessage> history = const [],
    List<String> memoryNotes = const [],
  }) async {
    final text = userText.trim();
    if (text.isEmpty) {
      return const AssistantTurn(reply: 'I didn\'t catch anything. Try again?');
    }
    final now = _now();
    final recent = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;

    final AiResponse response;
    try {
      response = await _provider.chat(
        messages: [
          AiMessage(AiRole.system, buildSystemPrompt(now, memoryNotes)),
          ...recent,
          AiMessage(AiRole.user, text),
        ],
        tools: _tools.specs,
      );
    } on AiProviderException catch (e) {
      final fallbackCalls = _fallbackDeterministicCalls(text, now);
      if (fallbackCalls.isNotEmpty) {
        final context = ToolContext(userText: text, now: now);
        final outcomes = <ToolOutcome>[];
        for (final call in fallbackCalls) {
          outcomes.add(await _tools.execute(call, context));
        }
        return AssistantTurn(reply: composeReply(outcomes), outcomes: outcomes);
      }
      return AssistantTurn(reply: e.message, failure: e.kind);
    } catch (_) {
      final fallbackCalls = _fallbackDeterministicCalls(text, now);
      if (fallbackCalls.isNotEmpty) {
        final context = ToolContext(userText: text, now: now);
        final outcomes = <ToolOutcome>[];
        for (final call in fallbackCalls) {
          outcomes.add(await _tools.execute(call, context));
        }
        return AssistantTurn(reply: composeReply(outcomes), outcomes: outcomes);
      }
      return const AssistantTurn(
        reply: 'I couldn\'t reach the assistant just now. Please try again.',
        failure: AiFailureKind.network,
      );
    }

    var effectiveCalls = response.toolCalls;
    if (effectiveCalls.isEmpty) {
      final fallbackCalls = _fallbackDeterministicCalls(text, now);
      if (fallbackCalls.isNotEmpty) {
        effectiveCalls = fallbackCalls;
      } else {
        final reply = (response.text ?? '').trim();
        return AssistantTurn(
          reply: reply.isEmpty
              ? 'I\'m not sure what you\'d like me to do. Could you rephrase?'
              : reply,
        );
      }
    }

    final context = ToolContext(userText: text, now: now);
    final outcomes = <ToolOutcome>[];
    for (final call in expandEntries(effectiveCalls, text).take(maxToolCalls)) {
      outcomes.add(await _tools.execute(call, context));
    }
    var reply = composeReply(outcomes);
    final advice = await _adviceFor(outcomes, response.text, now);
    if (advice != null) reply = '$reply\n\n$advice';
    return AssistantTurn(reply: reply, outcomes: outcomes);
  }

  static List<AiToolCall> _fallbackDeterministicCalls(String text, DateTime now) {
    final calls = <AiToolCall>[];
    final incMatch = _incomeRegex.firstMatch(text);
    final expMatch = _expenseRegex.firstMatch(text);
    if (incMatch != null || expMatch != null) {
      if (incMatch != null) {
        final incStr = (incMatch.group(1) ?? incMatch.group(2) ?? '').replaceAll(',', '');
        final incAmt = double.tryParse(incStr);
        if (incAmt != null && incAmt > 0) {
          calls.add(AiToolCall(
            id: 'fallback_inc_${now.millisecondsSinceEpoch}',
            name: 'addTransaction',
            arguments: {
              'amount': incAmt,
              'income': true,
              'title': 'Received',
            },
          ));
        }
      }
      if (expMatch != null) {
        final expStr = (expMatch.group(1) ?? expMatch.group(2) ?? '').replaceAll(',', '');
        final expAmt = double.tryParse(expStr);
        if (expAmt != null && expAmt > 0) {
          calls.add(AiToolCall(
            id: 'fallback_exp_${now.millisecondsSinceEpoch}',
            name: 'addTransaction',
            arguments: {
              'amount': expAmt,
              'income': false,
              'title': 'Spent',
            },
          ));
        }
      }
    }
    return calls;
  }

  static final _incomeRegex = RegExp(
    r'\b(?:received|recieved|earned|got|salary|income|refund(?:ed)?)\s+(?:(?:from|about)\s+)?(?:rs\.?|inr|\$|€|£)?\s*([0-9]+(?:\.[0-9]+)?)\b|\b(?:rs\.?|inr|\$|€|£)?\s*([0-9]+(?:\.[0-9]+)?)\s+(?:received|recieved|earned|got|as\s+income|salary)\b',
    caseSensitive: false,
  );
  static final _expenseRegex = RegExp(
    r'\b(?:spent|paid|expense|bought|cost|expended)\s+(?:(?:for|on|about)\s+)?(?:rs\.?|inr|\$|€|£)?\s*([0-9]+(?:\.[0-9]+)?)\b|\b(?:rs\.?|inr|\$|€|£)?\s*([0-9]+(?:\.[0-9]+)?)\s+(?:spent|paid|expense|as\s+expense)\b',
    caseSensitive: false,
  );

  /// Splits `entries` in logPulse/addTransaction calls so each item
  /// is validated, executed and undone on its own. Also ensures multi-amount
  /// financial statements (e.g. "received X and spent Y") execute both actions.
  static List<AiToolCall> expandEntries(List<AiToolCall> calls, [String? userText]) {
    final out = <AiToolCall>[];
    for (final c in calls) {
      final entries = c.arguments['entries'];
      if (entries is List && (c.name == 'logPulse' || c.name == 'addTransaction')) {
        var i = 0;
        for (final e in entries) {
          if (e is Map) {
            out.add(
              AiToolCall(
                id: '${c.id}_${i++}',
                name: c.name,
                arguments: Map<String, dynamic>.from(e),
              ),
            );
          }
        }
      } else {
        out.add(c);
      }
    }

    if (userText != null && out.any((c) => c.name == 'addTransaction')) {
      final txCalls = out.where((c) => c.name == 'addTransaction').toList();
      final incMatch = _incomeRegex.firstMatch(userText);
      final expMatch = _expenseRegex.firstMatch(userText);
      if (incMatch != null && expMatch != null) {
        final incStr = (incMatch.group(1) ?? incMatch.group(2) ?? '').replaceAll(',', '');
        final expStr = (expMatch.group(1) ?? expMatch.group(2) ?? '').replaceAll(',', '');
        final incAmt = double.tryParse(incStr);
        final expAmt = double.tryParse(expStr);

        final hasInc = txCalls.any((c) =>
            c.arguments['income'] == true ||
            c.arguments['income'] == 'true' ||
            double.tryParse('${c.arguments['amount']}'.replaceAll(',', '')) == incAmt);
        final hasExp = txCalls.any((c) =>
            c.arguments['income'] == false ||
            c.arguments['income'] == 'false' ||
            double.tryParse('${c.arguments['amount']}'.replaceAll(',', '')) == expAmt);

        if (incAmt != null && !hasInc) {
          out.insert(0, AiToolCall(
            id: 'extra_inc_${DateTime.now().millisecondsSinceEpoch}',
            name: 'addTransaction',
            arguments: {
              'amount': incAmt,
              'income': true,
              'title': 'Received',
            },
          ));
        }
        if (expAmt != null && !hasExp) {
          out.add(AiToolCall(
            id: 'extra_exp_${DateTime.now().millisecondsSinceEpoch}',
            name: 'addTransaction',
            arguments: {
              'amount': expAmt,
              'income': false,
              'title': 'Spent',
            },
          ));
        }
      }
    }

    return out;
  }

  /// One short piece of advice when several moments were just logged and
  /// there is something useful to connect. Never blocks or breaks the turn.
  Future<String?> _adviceFor(
    List<ToolOutcome> outcomes,
    String? modelText,
    DateTime now,
  ) async {
    try {
      final advisor = _advisor?.call();
      if (advisor == null) return null;
      final facts = [
        for (final o in outcomes)
          if (o.isWrite && o.fact != null) o.fact!,
      ];
      if (facts.isEmpty) return null;
      return await advisor.advise(facts: facts, now: now, modelText: modelText);
    } catch (_) {
      return null;
    }
  }

  /// "Done. I've set a reminder for 9 PM tonight." Built from results, so a
  /// failed tool is never reported as done.
  static String composeReply(List<ToolOutcome> outcomes) {
    final done = outcomes.where((o) => o.isWrite).toList();
    final rest = outcomes.where((o) => !o.isWrite).toList();
    final parts = <String>[];
    if (done.isNotEmpty) {
      parts.add('Done. ${done.map((o) => o.spoken).join(' ')}');
    }
    for (final o in rest) {
      parts.add(o.spoken);
    }

    final incomeTx = done.where((o) => o.label?.startsWith('Income added:') ?? false);
    final expenseTx = done.where((o) => o.label?.startsWith('Expense added:') ?? false);
    if (incomeTx.isNotEmpty && expenseTx.isNotEmpty) {
      double totalIncome = 0;
      double totalExpense = 0;
      for (final o in incomeTx) {
        final m = RegExp(r'Income added:\s*([0-9,]+(?:\.[0-9]+)?)').firstMatch(o.label ?? '');
        if (m != null) {
          totalIncome += double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
        }
      }
      for (final o in expenseTx) {
        final m = RegExp(r'Expense added:\s*([0-9,]+(?:\.[0-9]+)?)').firstMatch(o.label ?? '');
        if (m != null) {
          totalExpense += double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
        }
      }
      final net = totalIncome - totalExpense;
      final sign = net >= 0 ? '+' : '-';
      final netStr = formatAmount(net.abs());
      parts.add('Net: $sign$netStr.');
    }

    return parts.join(' ');
  }

  /// Compact on purpose: this is sent with every request.
  static String buildSystemPrompt(
    DateTime now, [
    List<String> notes = const [],
  ]) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    final off = now.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final oh = two(off.inHours.abs());
    final om = two(off.inMinutes.abs() % 60);
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
    final b = StringBuffer()
      ..writeln(
        'You are the assistant inside the OmniLife life-organiser app. '
        'Act on requests by calling tools. Reply in one short sentence '
        'only for chat or when you must ask something. Never invent data.',
      )
      ..writeln(
        'Now: ${days[now.weekday - 1]} $stamp, timezone ${now.timeZoneName} '
        '(UTC$sign$oh:$om). Resolve relative dates from this. Tool times are '
        'ISO-8601 local without offset, e.g. ${now.year}-${two(now.month)}-${two(now.day)}T21:00.',
      )
      ..writeln(
        'Reminders: tonight 21:00, morning 08:00, afternoon 14:00, evening '
        '18:00. daily/every day => repeat daily; weekly/every <weekday> => '
        'weekly; else none. When asked to set a reminder/remainder or add a task with a time or due date, call createReminder (or createTask with due). '
        'Multi-command requests: When a user gives multiple instructions or multiple actions in one sentence (for example: "I received 2500 and spent 500", or "add a task and set a reminder"), you MUST call the appropriate tool for EACH action. For money received/income call addTransaction with income: true, and for money spent/expense call addTransaction with income: false. You may either make multiple parallel tool calls or use the entries array. '
        'If key details are missing, ask one short question instead of guessing. '
        'Several facts in one message (sleep, water, meal, workout, mood...): '
        'call logPulse once with every fact listed in entries. Convert '
        'litres to ml; give sleep as hours.',
      );
    if (notes.isNotEmpty) {
      b.writeln('About the user: ${notes.join('; ')}');
    }
    return b.toString().trim();
  }
}
