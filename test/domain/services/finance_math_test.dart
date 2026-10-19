import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';
import 'package:omnilife/domain/services/finance_math.dart';

FinanceTransaction _tx(
  String id,
  double amount,
  TransactionCategory category,
  DateTime date, {
  bool income = false,
}) => FinanceTransaction(
  id: id,
  userId: 'u1',
  amount: amount,
  title: id,
  category: category,
  date: date,
  isIncome: income,
  createdAt: date,
  updatedAt: date,
);

void main() {
  group('spendByCategory', () {
    test('sums expenses per category, biggest first, ignoring income', () {
      final d = DateTime(2026, 3, 5);
      final slices = spendByCategory([
        _tx('a', 30, TransactionCategory.food, d),
        _tx('b', 10, TransactionCategory.food, d),
        _tx('c', 60, TransactionCategory.transport, d),
        _tx('pay', 1000, TransactionCategory.income, d, income: true),
      ]);
      expect(slices.map((s) => s.category), [
        TransactionCategory.transport,
        TransactionCategory.food,
      ]);
      expect(slices.first.amount, 60);
      expect(slices.first.share, closeTo(0.6, 1e-9));
      expect(slices.fold<double>(0, (a, s) => a + s.share), closeTo(1, 1e-9));
    });

    test('no spending gives no slices', () {
      expect(spendByCategory(const []), isEmpty);
    });
  });

  group('monthlyTotals', () {
    test('returns six months oldest first, with empty months as zeros', () {
      final totals = monthlyTotals([
        _tx('a', 40, TransactionCategory.food, DateTime(2026, 3, 2)),
        _tx(
          'pay',
          900,
          TransactionCategory.income,
          DateTime(2026, 3, 1),
          income: true,
        ),
        _tx('b', 15, TransactionCategory.food, DateTime(2025, 12, 30)),
      ], DateTime(2026, 3, 20));

      expect(totals, hasLength(6));
      expect(totals.first.month, DateTime(2025, 10, 1));
      expect(totals.last.month, DateTime(2026, 3, 1));
      expect(totals.last.income, 900);
      expect(totals.last.expense, 40);
      expect(totals.last.net, 860);
      expect(totals[2].expense, 15); // December
      expect(totals[3].expense, 0); // January is empty
    });
  });

  group('BudgetStatus', () {
    BudgetStatus status(double spent, double limit) => BudgetStatus(
      category: TransactionCategory.food,
      spent: spent,
      limit: limit,
    );

    test('on track says how much is left', () {
      final s = status(100, 500);
      expect(s.level, BudgetLevel.onTrack);
      expect(s.message, r'$400.00 left');
      expect(s.isOver, isFalse);
    });

    test('near the limit warns in words', () {
      final s = status(420, 500);
      expect(s.level, BudgetLevel.nearLimit);
      expect(s.message, r'$80.00 left, nearly used up');
    });

    test('over budget says by how much', () {
      final s = status(512.5, 500);
      expect(s.level, BudgetLevel.over);
      expect(s.isOver, isTrue);
      expect(s.message, r'Over budget by $12.50');
    });

    test('exactly on the limit is not over', () {
      expect(status(500, 500).isOver, isFalse);
    });

    test('no budget set is never over', () {
      final s = status(900, 0);
      expect(s.level, BudgetLevel.noBudget);
      expect(s.isOver, isFalse);
      expect(s.message, 'No budget set');
    });
  });
}
