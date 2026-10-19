// ignore_for_file: prefer_initializing_formals

import '../assistant/ai_provider.dart';
import '../services/pulse/daily_facts.dart';
import 'advice_context.dart';
import 'linked_advice_rules.dart';
import 'logged_fact.dart';
import 'text_hash.dart';

/// Turns what the user just logged into at most one short piece of advice.
abstract class LinkedAdvisor {
  /// Null means there is nothing worth saying. [modelText] is whatever the
  /// model wrote alongside its tool calls, reused when it is good enough.
  Future<String?> advise({
    required List<LoggedFact> facts,
    required DateTime now,
    String? modelText,
  });
}

/// Keeps model-written advice honest: short, specific to the user's own
/// numbers, no medical or causal claims, no generic filler.
class AdviceGuard {
  const AdviceGuard();

  static final _banned = RegExp(
    r'diagnos|disorder|disease|syndrome|medic|prescri|doctor|clinical|'
    r'\bcauses?\b|\bcaused\b|because of|due to|proves?\b|'
    r'stay hydrated|remember to|it.s important to',
    caseSensitive: false,
  );

  /// The cleaned text when it passes, otherwise null.
  String? accept(String? text, AdviceContext ctx) {
    if (text == null) return null;
    var t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceAll('**', '').replaceAll(RegExp(r'^"|"$'), '');
    if (t.length < 25 || t.length > 320) return null;
    if (_banned.hasMatch(t)) return null;
    final sentences = RegExp(r'[.!?](\s|$)').allMatches(t).length;
    if (sentences > 4) return null;
    if (!_usesNumbers(t, ctx)) return null;
    return t;
  }

  bool _usesNumbers(String text, AdviceContext ctx) {
    final tokens = <String>{};
    for (final f in ctx.logged) {
      final v = f.value;
      if (v == null) continue;
      switch (f.kind) {
        case LoggedKind.sleep:
          tokens.add('${v ~/ 60}');
          tokens.add((v / 60).toStringAsFixed(1));
        case LoggedKind.water:
          tokens.add('$v');
        case LoggedKind.mood:
        case LoggedKind.energy:
        case LoggedKind.workout:
        case LoggedKind.focus:
          tokens.add('$v');
        case LoggedKind.meal:
          break;
      }
    }
    final water = ctx.today.waterMl;
    if (water > 0) {
      tokens.add('$water');
      final l = water / 1000;
      tokens.add(
        l == l.roundToDouble() ? '${l.round()}' : l.toStringAsFixed(1),
      );
    }
    for (final t in tokens) {
      if (RegExp('(?<![\\d.])${RegExp.escape(t)}(?![\\d])').hasMatch(text)) {
        return true;
      }
    }
    return false;
  }
}

/// Rules decide whether there is anything to say; the model (when the key
/// exists) only words it. Order of preference: the model's own text from the
/// tool-calling reply, a cached rewrite, one compact extra call, then the
/// rule text. Never more than one extra call, never polled.
class DefaultLinkedAdvisor implements LinkedAdvisor {
  DefaultLinkedAdvisor({
    required Future<List<DailyFacts>> Function() loadDays,
    AiProvider? Function()? provider,
    TextCache? cache,
    this.rules = const LinkedAdviceRules(),
    this.guard = const AdviceGuard(),
    this.maxTokens = 350,
  }) : _loadDays = loadDays,
       _provider = provider,
       _cache = cache ?? InMemoryTextCache();

  final Future<List<DailyFacts>> Function() _loadDays;
  final AiProvider? Function()? _provider;
  final TextCache _cache;
  final LinkedAdviceRules rules;
  final AdviceGuard guard;
  final int maxTokens;

  @override
  Future<String?> advise({
    required List<LoggedFact> facts,
    required DateTime now,
    String? modelText,
  }) async {
    if (facts.isEmpty) return null;
    var days = const <DailyFacts>[];
    try {
      days = await _loadDays();
    } catch (_) {
      // Advice is a bonus; work from what was just said.
    }
    final ctx = AdviceContext.fromFacts(now: now, logged: facts, days: days);
    final draft = rules.evaluate(ctx);
    if (draft == null) return null; // nothing useful to say

    final fromModel = guard.accept(modelText, ctx);
    if (fromModel != null) return fromModel;

    AiProvider? provider;
    try {
      provider = _provider?.call();
    } catch (_) {
      provider = null;
    }
    if (provider == null || !provider.isConfigured) return draft.text;

    final key = 'linked_${stableHash(ctx.summary())}';
    final cached = await _cache.read(key);
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final reply = await completeText(provider, [
        const AiMessage(AiRole.system, _systemPrompt),
        AiMessage(
          AiRole.user,
          '${ctx.summary()}\nDraft to improve: ${draft.text}',
        ),
      ], maxTokens: maxTokens);
      final ok = guard.accept(reply, ctx);
      if (ok != null) {
        await _cache.write(key, ok);
        return ok;
      }
    } catch (_) {
      // Fall through to the rule text.
    }
    return draft.text;
  }

  static const _systemPrompt =
      'You are a calm friend who has looked at the user\'s day. Reply with '
      'one or two short sentences (under 45 words) that connect the signals '
      'below, using their actual numbers. Suggest, never diagnose: no '
      'medical claims, no claims that one thing causes another. You may end '
      'with one short offer that is actually useful, such as a reminder to '
      'wind down at a set time tonight; never offer a reminder to track or '
      'log something. Do not list what they did not log. No greeting, no '
      'filler.';
}
