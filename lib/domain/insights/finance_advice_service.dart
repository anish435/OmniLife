// ignore_for_file: prefer_initializing_formals

import '../assistant/ai_provider.dart';
import 'finance_suggestions.dart';
import 'text_hash.dart';

/// Optionally upgrades the rule-based suggestions with a written version.
///
/// At most one model call per sheet open, and none at all when the same
/// month and data were written up before (cached by month + data hash). The
/// model only ever sees aggregates. Anything that reads like a promise or a
/// pick of specific investments is thrown away and the rule-based tips stay.
class FinanceAdviceService {
  FinanceAdviceService({
    AiProvider? Function()? provider,
    TextCache? cache,
    this.maxTokens = 1100,
  }) : _provider = provider,
       _cache = cache ?? InMemoryTextCache();

  final AiProvider? Function()? _provider;
  final TextCache _cache;
  final int maxTokens;

  bool get canWrite {
    try {
      return _provider?.call()?.isConfigured ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The written version, or null when there is no key, no data, or the
  /// reply was not usable.
  Future<FinanceSuggestions?> write(FinanceSnapshot snapshot) async {
    if (!snapshot.hasData || !canWrite) return null;
    final key = snapshot.cacheKey;
    final cached = await _cache.read(key);
    if (cached != null) {
      final parsed = parse(cached);
      if (parsed != null) return parsed;
    }
    try {
      final reply = await completeText(_provider!()!, [
        const AiMessage(AiRole.system, _systemPrompt),
        AiMessage(AiRole.user, snapshot.promptContext()),
      ], maxTokens: maxTokens);
      if (reply == null) return null;
      final parsed = parse(reply);
      if (parsed == null) return null;
      await _cache.write(key, reply);
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static final _unsafe = RegExp(
    r'guarantee|risk.free|will (earn|return|grow|double|beat)|'
    r'\b(buy|sell|short)\b|\bticker|\bstock pick|\bnasdaq\b|\bnyse\b|'
    r'\b[A-Z]{2,5}:[A-Z]{2,5}\b|\$[A-Z]{2,5}\b|'
    r'you should invest|put (all|everything) in',
    caseSensitive: false,
  );

  /// Reads the reply back into sections. Null if it does not have the
  /// expected shape or contains anything unsafe.
  static FinanceSuggestions? parse(String reply) {
    if (_unsafe.hasMatch(reply)) return null;
    final sections = <SuggestionSection>[];
    String? current;
    var bullets = <String>[];
    void flush() {
      if (current != null && bullets.isNotEmpty) {
        sections.add(SuggestionSection(current, bullets));
      }
      bullets = <String>[];
    }

    for (final raw in reply.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final heading = _headingFor(line);
      if (heading != null) {
        flush();
        current = heading;
        continue;
      }
      if (current == null) continue;
      final text = line
          .replaceFirst(RegExp(r'^[-*•]\s*'), '')
          .replaceAll('**', '')
          .trim();
      if (text.length < 8 || text.length > 260) continue;
      bullets.add(text);
    }
    flush();

    final usable = sections.where((s) => s.bullets.length <= 6).toList();
    if (usable.length < 3) return null;
    // Keep the standard order and make sure the general section is there.
    final ordered = <SuggestionSection>[
      for (final t in FinanceSuggestions.titles)
        for (final s in usable)
          if (s.title == t) s,
    ];
    if (!ordered.any((s) => s.title == FinanceSuggestions.generalTitle)) {
      ordered.add(
        SuggestionSection(
          FinanceSuggestions.generalTitle,
          FinanceSuggestionRules.generalGuidance(),
        ),
      );
    }
    return FinanceSuggestions(ordered);
  }

  static String? _headingFor(String line) {
    final clean = line
        .replaceAll(RegExp(r'^#+\s*'), '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r':$'), '')
        .trim()
        .toLowerCase()
        .replaceAll('’', '\'');
    for (final t in FinanceSuggestions.titles) {
      if (t.toLowerCase() == clean) return t;
    }
    return null;
  }

  static const _systemPrompt =
      'You are a thoughtful friend who has looked at someone\'s month of '
      'spending and is talking it through with them, kindly and plainly. '
      'Use ONLY the numbers given; never invent figures and never name a '
      'currency. Write every bullet as a complete, natural sentence of 12 '
      'to 28 words that explains the why, not just a number. '
      'Use exactly these headings, each on its own line, each followed by '
      '1 to 3 bullets that start with "- ": '
      'Where it\'s going / Worth a look / Things you could do / '
      'Income and spending / On holdings and investing, in general. '
      'Rules: if no income is logged, say so and that it makes savings hard '
      'to judge; never suggest raising a budget as a way to save; only '
      'suggest trimming categories that are over budget or take a large '
      'share; give concrete targets with amounts, for example "try to keep '
      'Other under 100 next month"; stay calm, no alarm words. '
      'Under the last heading give only general education: emergency fund '
      'first, index funds versus savings, diversification, check fees. No '
      'specific securities, no promises about returns, nothing personalised '
      'about investing. No preamble, no disclaimer, under 250 words.';
}
