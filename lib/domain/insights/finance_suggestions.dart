import '../assistant/when_format.dart' show formatAmount;
import '../entities/finance_transaction.dart';
import 'text_hash.dart';

/// A repeated small spend, found by title on-device. The [label] is only
/// ever shown to the user; it is never part of the model context.
class RecurringSpend {
  const RecurringSpend({
    required this.label,
    required this.category,
    required this.count,
    required this.total,
  });

  final String label;
  final TransactionCategory category;
  final int count;
  final double total;
}

/// One month, reduced to aggregates. This is all the suggestions (and the
/// optional written version) are built from.
class FinanceSnapshot {
  const FinanceSnapshot({
    required this.month,
    required this.income,
    required this.expense,
    required this.byCategory,
    required this.budgets,
    this.previousExpenseByCategory = const {},
    this.previousIncome = 0,
    this.previousExpense = 0,
    this.recurring = const [],
    this.largestPurchase = 0,
    this.largestPurchaseCategory,
    this.transactionCount = 0,
  });

  final DateTime month;
  final double income;
  final double expense;
  final Map<TransactionCategory, double> byCategory;
  final Map<TransactionCategory, double> budgets;
  final Map<TransactionCategory, double> previousExpenseByCategory;
  final double previousIncome;
  final double previousExpense;
  final List<RecurringSpend> recurring;
  final double largestPurchase;
  final TransactionCategory? largestPurchaseCategory;
  final int transactionCount;

  bool get hasData => expense > 0 || income > 0;
  bool get hasPrevious => previousExpense > 0 || previousIncome > 0;

  /// Share of income kept, as a fraction (can be negative), or null when
  /// there is no income to compare against.
  double? get savingsRate => income > 0 ? (income - expense) / income : null;

  factory FinanceSnapshot.fromTransactions({
    required DateTime month,
    required Iterable<FinanceTransaction> current,
    Iterable<FinanceTransaction> previous = const [],
    Map<TransactionCategory, double> budgets = const {},
  }) {
    var income = 0.0;
    var expense = 0.0;
    final byCat = <TransactionCategory, double>{};
    var largest = 0.0;
    TransactionCategory? largestCat;
    var count = 0;
    final groups = <String, List<FinanceTransaction>>{};
    for (final t in current) {
      if (t.amount <= 0) continue;
      count++;
      if (t.isIncome) {
        income += t.amount;
        continue;
      }
      expense += t.amount;
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
      if (t.amount > largest) {
        largest = t.amount;
        largestCat = t.category;
      }
      final key = t.title.trim().toLowerCase();
      if (key.isNotEmpty) groups.putIfAbsent(key, () => []).add(t);
    }

    var prevIncome = 0.0;
    var prevExpense = 0.0;
    final prevByCat = <TransactionCategory, double>{};
    for (final t in previous) {
      if (t.amount <= 0) continue;
      if (t.isIncome) {
        prevIncome += t.amount;
      } else {
        prevExpense += t.amount;
        prevByCat[t.category] = (prevByCat[t.category] ?? 0) + t.amount;
      }
    }

    // "Small" means each one is a minor part of the month, but they repeat.
    final recurring = <RecurringSpend>[];
    for (final g in groups.values) {
      if (g.length < 3 || expense <= 0) continue;
      final total = g.fold<double>(0, (a, t) => a + t.amount);
      final avg = total / g.length;
      if (avg <= expense * 0.05 && total >= expense * 0.04) {
        recurring.add(
          RecurringSpend(
            label: g.first.title.trim(),
            category: g.first.category,
            count: g.length,
            total: total,
          ),
        );
      }
    }
    recurring.sort((a, b) => b.total.compareTo(a.total));

    return FinanceSnapshot(
      month: DateTime(month.year, month.month, 1),
      income: income,
      expense: expense,
      byCategory: byCat,
      budgets: {
        for (final e in budgets.entries)
          if (e.key != TransactionCategory.income && e.value > 0)
            e.key: e.value,
      },
      previousExpenseByCategory: prevByCat,
      previousIncome: prevIncome,
      previousExpense: prevExpense,
      recurring: recurring.take(3).toList(),
      largestPurchase: largest,
      largestPurchaseCategory: largestCat,
      transactionCount: count,
    );
  }

  /// Aggregates only, a few hundred tokens at most. No titles, no notes,
  /// no individual transactions.
  String promptContext() {
    final b = StringBuffer();
    b.writeln('Month: ${month.year}-${month.month.toString().padLeft(2, '0')}');
    b.writeln(
      'Income ${_n(income)}, spending ${_n(expense)}'
      '${savingsRate == null ? '' : ', kept ${(savingsRate! * 100).round()}%'}',
    );
    if (hasPrevious) {
      b.writeln(
        'Last month: income ${_n(previousIncome)}, spending '
        '${_n(previousExpense)}',
      );
    }
    final cats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in cats.take(5)) {
      final prev = previousExpenseByCategory[e.key];
      final share = expense > 0 ? (e.value / expense * 100).round() : 0;
      final budget = budgets[e.key];
      b.writeln(
        '${e.key.name}: ${_n(e.value)} ($share%)'
        '${prev != null && prev > 0 ? ', last month ${_n(prev)}' : ''}'
        '${budget != null ? ', budget ${_n(budget)}' : ''}',
      );
    }
    for (final r in recurring) {
      b.writeln(
        'Repeated small spends in ${r.category.name}: ${r.count} times, '
        '${_n(r.total)} total',
      );
    }
    if (expense > 0 && largestPurchase / expense >= 0.3) {
      b.writeln(
        'One purchase is ${(largestPurchase / expense * 100).round()}% of '
        'spending',
      );
    }
    return b.toString().trim();
  }

  /// Same data, same hash. Used with the month as the cache key.
  String get dataHash => stableHash(promptContext());

  String get cacheKey =>
      'finance_${month.year}-${month.month.toString().padLeft(2, '0')}_$dataHash';

  static String _n(double v) => formatAmount(v);
}

class SuggestionSection {
  const SuggestionSection(this.title, this.bullets);

  final String title;
  final List<String> bullets;
}

class FinanceSuggestions {
  const FinanceSuggestions(this.sections, {this.hasData = true});

  final List<SuggestionSection> sections;
  final bool hasData;

  static const disclaimer = 'General guidance, not financial advice.';

  static const whereTitle = 'Where it\'s going';
  static const lookTitle = 'Worth a look';
  static const doTitle = 'Things you could do';
  static const incomeTitle = 'Income and spending';
  static const generalTitle = 'On holdings and investing, in general';

  static const titles = [
    whereTitle,
    lookTitle,
    doTitle,
    incomeTitle,
    generalTitle,
  ];

  SuggestionSection? section(String title) {
    for (final s in sections) {
      if (s.title == title) return s;
    }
    return null;
  }
}

String categoryWord(TransactionCategory c) => switch (c) {
  TransactionCategory.income => 'Income',
  TransactionCategory.food => 'Food',
  TransactionCategory.transport => 'Transport',
  TransactionCategory.utilities => 'Utilities',
  TransactionCategory.entertainment => 'Entertainment',
  TransactionCategory.shopping => 'Shopping',
  TransactionCategory.health => 'Health',
  TransactionCategory.other => 'Other things',
};

/// Plain rule-based tips from the real month. Works with no key and no
/// network, so the sheet is never empty-handed.
class FinanceSuggestionRules {
  const FinanceSuggestionRules();

  static const _discretionary = {
    TransactionCategory.shopping,
    TransactionCategory.entertainment,
    TransactionCategory.food,
    TransactionCategory.other,
  };

  static List<String> generalGuidance() => const [
    'Money you may need within a few years usually sits better in a savings '
        'account than in investments that can fall in value.',
    'For long-term money, many people use low-cost, broad index funds '
        'rather than picking individual investments.',
    'Spreading money across different kinds of assets limits the damage if '
        'one of them does badly.',
    'Check the fees on anything you hold. Small yearly percentages add up '
        'over decades.',
    'These are general ideas for learning, not advice for your situation.',
  ];

  FinanceSuggestions build(FinanceSnapshot s) {
    final general = SuggestionSection(
      FinanceSuggestions.generalTitle,
      generalGuidance(),
    );
    if (!s.hasData) {
      return FinanceSuggestions([
        const SuggestionSection('Getting started', [
          'Nothing to go on for this month yet. Add a few expenses and '
              'income and I\'ll point at where the money goes.',
        ]),
        general,
      ], hasData: false);
    }

    final out = <SuggestionSection>[];
    final where = _where(s);
    final look = _look(s);
    final doThis = _do(s);
    final income = _income(s);
    if (where.isNotEmpty) {
      out.add(SuggestionSection(FinanceSuggestions.whereTitle, where));
    }
    if (look.isNotEmpty) {
      out.add(SuggestionSection(FinanceSuggestions.lookTitle, look));
    }
    if (doThis.isNotEmpty) {
      out.add(SuggestionSection(FinanceSuggestions.doTitle, doThis));
    }
    if (income.isNotEmpty) {
      out.add(SuggestionSection(FinanceSuggestions.incomeTitle, income));
    }
    out.add(general);
    return FinanceSuggestions(out);
  }

  List<MapEntry<TransactionCategory, double>> _top(FinanceSnapshot s) {
    final list = s.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  int _pct(double part, double whole) =>
      whole <= 0 ? 0 : (part / whole * 100).round();

  String _n(double v) => formatAmount(v.roundToDouble());

  /// Rounds to a tidy number for a target (nearest 10, at least 10).
  double _tidy(double v) {
    final r = (v / 10).round() * 10;
    return (r < 10 ? 10 : r).toDouble();
  }

  List<String> _where(FinanceSnapshot s) {
    final out = <String>[];
    if (s.expense <= 0) return out;
    for (final e in _top(s).take(3)) {
      final prev = s.previousExpenseByCategory[e.key] ?? 0;
      var change = '';
      if (prev > 0) {
        final delta = ((e.value - prev) / prev * 100).round();
        if (delta >= 10) {
          change = ', up $delta% from last month';
        } else if (delta <= -10) {
          change = ', down ${-delta}% from last month';
        }
      }
      out.add(
        '${categoryWord(e.key)}: ${_n(e.value)}, '
        '${_pct(e.value, s.expense)}% of what you spent$change.',
      );
    }
    if (s.previousExpense > 0) {
      final delta = ((s.expense - s.previousExpense) / s.previousExpense * 100)
          .round();
      if (delta.abs() >= 5) {
        out.add(
          'Overall you spent ${_n(s.expense)}, '
          '${delta > 0 ? 'up' : 'down'} ${delta.abs()}% on last month '
          '(${_n(s.previousExpense)}).',
        );
      }
    }
    // Budgets: overs first, then close calls, then one comfortable one.
    final overs = <String>[];
    final close = <String>[];
    final fine = <String>[];
    for (final e in s.budgets.entries) {
      final spent = s.byCategory[e.key] ?? 0;
      final name = categoryWord(e.key);
      if (spent > e.value) {
        overs.add(
          '$name is ${_n(spent - e.value)} over its ${_n(e.value)} budget.',
        );
      } else if (spent >= e.value * 0.85) {
        close.add(
          '$name is at ${_pct(spent, e.value)}% of its ${_n(e.value)} budget.',
        );
      } else if (spent > 0 && spent <= e.value * 0.6) {
        fine.add(
          '$name is comfortably under budget (${_n(spent)} of '
          '${_n(e.value)}).',
        );
      }
    }
    out.addAll([...overs, ...close, if (fine.isNotEmpty) fine.first].take(3));
    return out;
  }

  List<String> _look(FinanceSnapshot s) {
    final out = <String>[];
    if (s.expense <= 0) return out;
    for (final r in s.recurring.take(2)) {
      out.add(
        '${r.label} came up ${r.count} times for ${_n(r.total)} in total. '
        'Small ones add up quickly.',
      );
    }
    // The biggest riser that is not already one of the top three.
    final top3 = _top(s).take(3).map((e) => e.key).toSet();
    TransactionCategory? riser;
    var riserPct = 0;
    for (final e in s.byCategory.entries) {
      final prev = s.previousExpenseByCategory[e.key] ?? 0;
      if (prev <= 0 || top3.contains(e.key)) continue;
      final delta = ((e.value - prev) / prev * 100).round();
      if (delta >= 25 && delta > riserPct && e.value >= s.expense * 0.05) {
        riser = e.key;
        riserPct = delta;
      }
    }
    if (riser != null) {
      out.add('${categoryWord(riser)} rose $riserPct% from last month.');
    }
    if (s.largestPurchase > 0 && s.transactionCount >= 3) {
      final share = _pct(s.largestPurchase, s.expense);
      if (share >= 30) {
        out.add(
          'One ${s.largestPurchaseCategory == null ? '' : '${categoryWord(s.largestPurchaseCategory!).toLowerCase()} '}'
          'purchase of ${_n(s.largestPurchase)} is $share% of the month.',
        );
      }
    }
    for (final e in _top(s)) {
      if (!s.budgets.containsKey(e.key) && _pct(e.value, s.expense) >= 20) {
        out.add(
          '${categoryWord(e.key)} takes ${_pct(e.value, s.expense)}% of your '
          'spending but has no budget.',
        );
        break;
      }
    }
    return out.take(4).toList();
  }

  List<String> _do(FinanceSnapshot s) {
    final out = <String>[];
    if (s.expense <= 0) return out;

    // The biggest overspend, else the biggest discretionary category.
    MapEntry<TransactionCategory, double>? overEntry;
    var overBy = 0.0;
    for (final e in s.budgets.entries) {
      final over = (s.byCategory[e.key] ?? 0) - e.value;
      if (over > overBy) {
        overBy = over;
        overEntry = e;
      }
    }
    if (overEntry != null) {
      out.add(
        'Try to bring ${categoryWord(overEntry.key).toLowerCase()} back to '
        'its ${_n(overEntry.value)} budget next month. That is about '
        '${_n(overBy)} less.',
      );
    } else {
      for (final e in _top(s)) {
        if (_discretionary.contains(e.key) && _pct(e.value, s.expense) >= 20) {
          final target = _tidy(e.value * 0.1);
          out.add(
            'Trimming ${categoryWord(e.key).toLowerCase()} by about 10% '
            'would free around ${_n(target)} a month.',
          );
          break;
        }
      }
    }

    // A budget for the biggest category that has none.
    for (final e in _top(s)) {
      if (!s.budgets.containsKey(e.key) && _pct(e.value, s.expense) >= 15) {
        final limit = ((e.value * 0.9) / 50).round() * 50;
        if (limit > 0) {
          out.add(
            'Set a ${categoryWord(e.key).toLowerCase()} budget. Around '
            '${_n(limit.toDouble())} would be a bit under this month.',
          );
        }
        break;
      }
    }

    final left = s.income - s.expense;
    if (s.income > 0 && left < 0) {
      out.add(
        'Spending ran ${_n(-left)} above income. Trimming your top two '
        'categories by 10% would cover roughly '
        '${_n(_top(s).take(2).fold<double>(0, (a, e) => a + e.value) * 0.1)} '
        'of that.',
      );
    } else if (s.income > 0 && left > 0) {
      final move = _tidy(left * 0.5);
      out.add(
        'You have ${_n(left)} left over. Moving a fixed amount, say '
        '${_n(move)}, to savings right after income lands makes it automatic.',
      );
    }

    final low = s.expense * 3;
    final high = s.expense * 6;
    out.add(
      'If you don\'t have an emergency fund yet, build that first: 3 to 6 '
      'months of spending is about ${_n(low)} to ${_n(high)}.',
    );

    if (s.largestPurchase > 0 &&
        s.transactionCount >= 3 &&
        _pct(s.largestPurchase, s.expense) >= 30) {
      out.add(
        'For big purchases, set a little aside each month so a single month '
        'doesn\'t take the whole hit.',
      );
    }
    return out.take(5).toList();
  }

  List<String> _income(FinanceSnapshot s) {
    final rate = s.savingsRate;
    if (rate == null) {
      return const [
        'No income is logged for this month, so I can\'t work out how much '
            'you\'re keeping. Add it and this will fill in.',
      ];
    }
    final out = <String>[];
    final pct = (rate * 100).round();
    if (rate < 0) {
      out.add('You spent ${-pct}% more than you earned this month.');
    } else if (rate < 0.1) {
      out.add(
        'You kept $pct% of your income. Even a few more points a month '
        'adds up over a year.',
      );
    } else if (rate < 0.2) {
      out.add(
        'You kept $pct% of your income. Many people aim for around 20% '
        'when they can.',
      );
    } else {
      out.add('You kept $pct% of your income, a solid cushion.');
    }
    if (s.previousIncome > 0) {
      final prev =
          ((s.previousIncome - s.previousExpense) / s.previousIncome * 100)
              .round();
      out.add('Last month you kept $prev%.');
    }
    return out;
  }
}
