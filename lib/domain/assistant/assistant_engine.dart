// ignore_for_file: prefer_initializing_formals

import '../insights/linked_advisor.dart';
import 'ai_provider.dart';
import 'assistant_tool.dart';

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
      return AssistantTurn(reply: e.message, failure: e.kind);
    } catch (_) {
      return const AssistantTurn(
        reply: 'I couldn\'t reach the assistant just now. Please try again.',
        failure: AiFailureKind.network,
      );
    }

    if (response.toolCalls.isEmpty) {
      final reply = (response.text ?? '').trim();
      return AssistantTurn(
        reply: reply.isEmpty
            ? 'I\'m not sure what you\'d like me to do. Could you rephrase?'
            : reply,
      );
    }

    final context = ToolContext(userText: text, now: now);
    final outcomes = <ToolOutcome>[];
    for (final call in expandEntries(response.toolCalls).take(maxToolCalls)) {
      outcomes.add(await _tools.execute(call, context));
    }
    var reply = composeReply(outcomes);
    final advice = await _adviceFor(outcomes, response.text, now);
    if (advice != null) reply = '$reply\n\n$advice';
    return AssistantTurn(reply: reply, outcomes: outcomes);
  }

  /// The model lists several logged facts as `entries` in one logPulse call
  /// (it will not make parallel calls reliably). Split them so each fact is
  /// validated, executed and undone on its own.
  static List<AiToolCall> expandEntries(List<AiToolCall> calls) {
    final out = <AiToolCall>[];
    for (final c in calls) {
      final entries = c.arguments['entries'];
      if (c.name == 'logPulse' && entries is List) {
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
        'weekly; else none. Money is an expense unless received/earned/salary. '
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
