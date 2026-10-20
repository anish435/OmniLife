import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';
import 'package:omnilife/domain/insights/finance_advice_service.dart';
import 'package:omnilife/domain/insights/finance_suggestions.dart';
import 'package:omnilife/domain/insights/text_hash.dart';

final _month = DateTime(2026, 10, 1);

FinanceTransaction _tx(
  double amount,
  TransactionCategory c, {
  String title = 'Thing',
  bool income = false,
  DateTime? date,
}) {
  final d = date ?? DateTime(2026, 10, 10);
  return FinanceTransaction(
    id: '${amount}_${title}_${d.microsecondsSinceEpoch}_${c.name}',
    userId: 'u1',
    amount: amount,
    title: title,
    category: c,
    date: d,
    isIncome: income,
    createdAt: d,
    updatedAt: d,
  );
}

FinanceSnapshot _snap(
  List<FinanceTransaction> current, {
  List<FinanceTransaction> previous = const [],
  Map<TransactionCategory, double> budgets = const {},
}) => FinanceSnapshot.fromTransactions(
  month: _month,
  current: current,
  previous: previous,
  budgets: budgets,
);

String _all(FinanceSuggestions s) =>
    [for (final sec in s.sections) ...sec.bullets].join('\n');

class _Provider implements AiProvider, TextCompleter {
  _Provider(this.reply, {this.configured = true});
  final String? reply;
  final bool configured;
  final List<List<AiMessage>> requests = [];

  @override
  bool get isConfigured => configured;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    required List<AiToolSpec> tools,
  }) async => const AiResponse();

  @override
  Future<String?> complete({
    required List<AiMessage> messages,
    int maxTokens = 400,
  }) async {
    requests.add(messages);
    return reply;
  }
}

const _written = '''
Where it's going
- Food is 42% of what you spent, about 3,200 this month.
Worth a look
- Coffee runs add up over the month.
Things you could do
- Trim food by about 300 next month.
Income and spending
- You kept 24% of your income this month.
On holdings and investing, in general
- Keep an emergency fund before investing, and check fees on anything you hold.
''';

void main() {
  const rules = FinanceSuggestionRules();

  group('rule-based suggestions', () {
    test('a high spending category shows its share and a trim target', () {
      final s = rules.build(
        _snap([
          _tx(3200, TransactionCategory.shopping),
          _tx(900, TransactionCategory.transport),
          _tx(400, TransactionCategory.utilities),
          _tx(9000, TransactionCategory.income, income: true),
        ]),
      );
      final where = s.section(FinanceSuggestions.whereTitle)!.bullets;
      expect(where.first, contains('Shopping: 3,200'));
      expect(where.first, contains('71%'));
      final todo = s.section(FinanceSuggestions.doTitle)!.bullets.join(' ');
      expect(todo, contains('Trimming shopping by about 10%'));
      expect(todo, contains('320'));
    });

    test('change versus last month is spelled out', () {
      final s = rules.build(
        _snap(
          [_tx(1200, TransactionCategory.food)],
          previous: [_tx(1000, TransactionCategory.food)],
        ),
      );
      expect(_all(s), contains('up 20% from last month'));
      expect(_all(s), contains('up 20% on last month'));
    });

    test('over and near budget are said in plain words', () {
      final s = rules.build(
        _snap(
          [
            _tx(1500, TransactionCategory.shopping),
            _tx(950, TransactionCategory.food),
          ],
          budgets: {
            TransactionCategory.shopping: 1000,
            TransactionCategory.food: 1000,
          },
        ),
      );
      final text = _all(s);
      expect(text, contains('Shopping is 500 over its 1,000 budget'));
      expect(text, contains('Food is at 95% of its 1,000 budget'));
      expect(text, contains('bring shopping back to its 1,000 budget'));
    });

    test('a surplus suggests moving a fixed amount and an emergency fund', () {
      final s = rules.build(
        _snap([
          _tx(2000, TransactionCategory.food),
          _tx(6000, TransactionCategory.income, income: true),
        ]),
      );
      final todo = s.section(FinanceSuggestions.doTitle)!.bullets.join(' ');
      expect(todo, contains('4,000 left over'));
      expect(todo, contains('2,000'));
      expect(todo, contains('emergency fund'));
      expect(todo, contains('6,000 to 12,000'));
      final income = s.section(FinanceSuggestions.incomeTitle)!.bullets.first;
      expect(income, contains('67%'));
    });

    test('spending above income is called out', () {
      final s = rules.build(
        _snap([
          _tx(5000, TransactionCategory.shopping),
          _tx(4000, TransactionCategory.income, income: true),
        ]),
      );
      expect(_all(s), contains('Spending ran 1,000 above income'));
      expect(_all(s), contains('spent 25% more than you earned'));
    });

    test('repeated small spends and a single big purchase are noticed', () {
      final coffee = [
        for (var i = 1; i <= 6; i++)
          _tx(
            100,
            TransactionCategory.food,
            title: 'Coffee',
            date: DateTime(2026, 10, i),
          ),
      ];
      final s = rules.build(
        _snap([...coffee, _tx(3000, TransactionCategory.shopping)]),
      );
      final look = s.section(FinanceSuggestions.lookTitle)!.bullets.join(' ');
      expect(look, contains('Coffee came up 6 times for 600'));
      expect(look, contains('purchase of 3,000'));
      expect(
        s.section(FinanceSuggestions.doTitle)!.bullets.join(' '),
        contains('big purchases'),
      );
    });

    test('no income logged is said, not guessed', () {
      final s = rules.build(_snap([_tx(500, TransactionCategory.food)]));
      expect(
        s.section(FinanceSuggestions.incomeTitle)!.bullets.single,
        contains('No income is logged'),
      );
    });

    test('an empty month is never empty-handed', () {
      final s = rules.build(_snap(const []));
      expect(s.hasData, isFalse);
      expect(s.sections.first.title, 'Getting started');
      expect(s.section(FinanceSuggestions.generalTitle), isNotNull);
    });

    test(
      'general guidance is framed as education, with no picks or promises',
      () {
        final text = FinanceSuggestionRules.generalGuidance().join(' ');
        expect(text, contains('index funds'));
        expect(text, contains('fees'));
        expect(text, contains('not advice for your situation'));
        expect(
          text,
          isNot(matches(RegExp(r'guarantee|will return|\b[A-Z]{3,5}\b'))),
        );
        expect(
          FinanceSuggestions.disclaimer,
          'General guidance, not financial advice.',
        );
      },
    );
  });

  group('snapshot context and cache key', () {
    test('context is aggregates only: no titles', () {
      final snap = _snap([
        for (var i = 1; i <= 4; i++)
          _tx(
            50,
            TransactionCategory.food,
            title: 'Secret cafe name',
            date: DateTime(2026, 10, i),
          ),
        _tx(2000, TransactionCategory.shopping, title: 'Private thing'),
      ]);
      final ctx = snap.promptContext();
      expect(ctx, isNot(contains('Secret cafe')));
      expect(ctx, isNot(contains('Private thing')));
      expect(ctx, contains('food'));
      expect(ctx.length, lessThan(900));
    });

    test('same data gives the same key, changed data a new one', () {
      final a = _snap([_tx(100, TransactionCategory.food)]);
      final b = _snap([_tx(100, TransactionCategory.food)]);
      final c = _snap([_tx(101, TransactionCategory.food)]);
      expect(a.cacheKey, b.cacheKey);
      expect(a.cacheKey, isNot(c.cacheKey));
      expect(a.cacheKey, startsWith('finance_2026-10_'));
    });
  });

  group('written version', () {
    final snap = _snap([
      _tx(3200, TransactionCategory.food),
      _tx(9000, TransactionCategory.income, income: true),
    ]);

    test('no key means null and no request', () async {
      final p = _Provider(_written, configured: false);
      final svc = FinanceAdviceService(provider: () => p);
      expect(svc.canWrite, isFalse);
      expect(await svc.write(snap), isNull);
      expect(p.requests, isEmpty);
    });

    test('no provider registered is fine too', () async {
      final svc = FinanceAdviceService();
      expect(await svc.write(snap), isNull);
    });

    test('one call per month and data, cached afterwards', () async {
      final p = _Provider(_written);
      final cache = InMemoryTextCache();
      final svc = FinanceAdviceService(provider: () => p, cache: cache);
      final first = await svc.write(snap);
      final second = await svc.write(snap);
      expect(first!.sections, hasLength(5));
      expect(second!.sections, hasLength(5));
      expect(p.requests, hasLength(1));
      expect(cache.store.keys.single, 'v2_${snap.cacheKey}');
      // Changed data is a new request.
      await svc.write(_snap([_tx(10, TransactionCategory.food)]));
      expect(p.requests, hasLength(2));
    });

    test('only aggregates are sent', () async {
      final p = _Provider(_written);
      final svc = FinanceAdviceService(provider: () => p);
      await svc.write(
        _snap([_tx(3200, TransactionCategory.food, title: 'Joes Diner')]),
      );
      final sent = p.requests.single.map((m) => m.content).join('\n');
      expect(sent, isNot(contains('Joes')));
    });

    test('replies that pick securities or promise returns are discarded', () {
      expect(
        FinanceAdviceService.parse(
          _written.replaceFirst(
            'check fees on anything you hold',
            'buy NASDAQ:TSLA, it will return 20%',
          ),
        ),
        isNull,
      );
      expect(
        FinanceAdviceService.parse(
          _written.replaceFirst('Keep an', 'Guaranteed growth: keep an'),
        ),
        isNull,
      );
      expect(FinanceAdviceService.parse('Just some rambling text.'), isNull);
    });

    test('a reply missing the general section gets the standard one', () {
      final trimmed = _written.substring(
        0,
        _written.indexOf('On holdings and investing'),
      );
      final parsed = FinanceAdviceService.parse(trimmed)!;
      expect(
        parsed.section(FinanceSuggestions.generalTitle)!.bullets,
        FinanceSuggestionRules.generalGuidance(),
      );
    });
  });
}
