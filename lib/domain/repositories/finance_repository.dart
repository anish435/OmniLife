import '../entities/finance_transaction.dart';

abstract class FinanceRepository {
  /// Fetches all transactions for a specific user and month
  Future<List<FinanceTransaction>> getTransactions(String userId, {int? month, int? year});

  /// Creates a new transaction
  Future<FinanceTransaction> createTransaction(FinanceTransaction transaction);

  /// Updates an existing transaction
  Future<FinanceTransaction> updateTransaction(FinanceTransaction transaction);

  /// Deletes a transaction
  Future<void> deleteTransaction(String transactionId);
}
