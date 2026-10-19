import '../entities/finance_transaction.dart';

/// Income and spending for one calendar month.
class MonthlyTotals {
  const MonthlyTotals(this.month, this.income, this.expense);

  /// First day of the month.
  final DateTime month;
  final double income;
  final double expense;

  double get net => income - expense;
}

/// One slice of the spending-by-category chart.
class CategorySpend {
  const CategorySpend(this.category, this.amount, this.share);

  final TransactionCategory category;
  final double amount;

  /// Fraction of all spending, 0 to 1.
  final double share;
}

/// Spending per category, biggest first. Income and zero amounts are left out.
List<CategorySpend> spendByCategory(Iterable<FinanceTransaction> txs) {
  final totals = <TransactionCategory, double>{};
  for (final t in txs) {
    if (t.isIncome || t.amount <= 0) continue;
    totals[t.category] = (totals[t.category] ?? 0) + t.amount;
  }
  final sum = totals.values.fold<double>(0, (a, b) => a + b);
  if (sum <= 0) return const [];
  final list = [
    for (final e in totals.entries)
      CategorySpend(e.key, e.value, e.value / sum),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  return list;
}

/// Income vs spending for the [months] months ending at [endMonth],
/// oldest first. Months with no transactions are present with zeros so the
/// chart always shows a steady run of months.
List<MonthlyTotals> monthlyTotals(
  Iterable<FinanceTransaction> txs,
  DateTime endMonth, {
  int months = 6,
}) {
  final result = <MonthlyTotals>[];
  for (var i = months - 1; i >= 0; i--) {
    final month = DateTime(endMonth.year, endMonth.month - i, 1);
    var income = 0.0;
    var expense = 0.0;
    for (final t in txs) {
      if (t.date.year != month.year || t.date.month != month.month) continue;
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    result.add(MonthlyTotals(month, income, expense));
  }
  return result;
}

enum BudgetLevel { noBudget, onTrack, nearLimit, over }

/// How one category is doing against its monthly budget.
class BudgetStatus {
  const BudgetStatus({
    required this.category,
    required this.spent,
    required this.limit,
  });

  final TransactionCategory category;
  final double spent;
  final double limit;

  bool get hasBudget => limit > 0;

  /// Share of the budget used, 0 and up (can exceed 1 when over).
  double get used => hasBudget ? spent / limit : 0;

  double get remaining => limit - spent;

  BudgetLevel get level {
    if (!hasBudget) return BudgetLevel.noBudget;
    if (spent > limit) return BudgetLevel.over;
    if (used >= 0.8) return BudgetLevel.nearLimit;
    return BudgetLevel.onTrack;
  }

  bool get isOver => level == BudgetLevel.over;

  /// A plain-words summary, for example "Over budget by $12.00".
  String get message {
    switch (level) {
      case BudgetLevel.noBudget:
        return 'No budget set';
      case BudgetLevel.over:
        return 'Over budget by ${_money(spent - limit)}';
      case BudgetLevel.nearLimit:
        return '${_money(remaining)} left, nearly used up';
      case BudgetLevel.onTrack:
        return '${_money(remaining)} left';
    }
  }

  static String _money(double v) => '\$${v.toStringAsFixed(2)}';
}
