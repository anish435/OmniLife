import 'package:flutter/foundation.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/local/local_finance_data_source.dart';
import '../datasources/remote/firestore_paths.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';
import '../models/finance_transaction_model.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  FinanceRepositoryImpl({
    LocalFinanceDataSource? localDataSource,
    UserScopedFirestoreDataSource? remoteDataSource,
  })  : _localDataSource = localDataSource ?? LocalFinanceDataSource(),
        _remoteDataSource = remoteDataSource ?? UserScopedFirestoreDataSource();

  final LocalFinanceDataSource _localDataSource;
  final UserScopedFirestoreDataSource _remoteDataSource;

  final Map<String, FinanceTransactionModel> _memoryCache = {};

  void _syncToRemote(String userId, FinanceTransactionModel model) {
    if (kIsWeb) {
      _remoteDataSource
          .set(userId, FirestoreCollections.expenses, model.id, model.toFirestoreMap())
          .catchError((_) {});
    } else {
      _remoteDataSource
          .set(userId, FirestoreCollections.expenses, model.id, model.toFirestoreMap())
          .catchError((_) {});
    }
  }

  void _deleteFromRemote(String userId, String id) {
    _remoteDataSource
        .delete(userId, FirestoreCollections.expenses, id)
        .catchError((_) {});
  }

  @override
  Future<List<FinanceTransaction>> getTransactions(String userId, {int? month, int? year}) async {
    if (kIsWeb) {
      try {
        final docs = await _remoteDataSource.list(
          userId,
          FirestoreCollections.expenses,
        );
        var transactions = docs.map(FinanceTransactionModel.fromMap).toList();
        if (month != null && year != null) {
          transactions = transactions.where((e) => e.date.year == year && e.date.month == month).toList();
        }
        transactions.sort((a, b) => b.date.compareTo(a.date));
        for (final e in transactions) {
          _memoryCache[e.id] = e;
        }
        return transactions;
      } catch (_) {
        var filtered = _memoryCache.values.where((e) => e.userId == userId);
        if (month != null && year != null) {
           filtered = filtered.where((e) => e.date.year == year && e.date.month == month);
        }
        final list = filtered.toList()..sort((a, b) => b.date.compareTo(a.date));
        return list;
      }
    }

    final localTxs = await _localDataSource.getTransactions(userId, month: month, year: year);
    for (final e in localTxs) {
      _memoryCache[e.id] = e;
    }
    return localTxs;
  }

  @override
  Future<FinanceTransaction> createTransaction(FinanceTransaction transaction) async {
    final model = FinanceTransactionModel.fromEntity(transaction);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.insertTransaction(model);
    }

    _syncToRemote(transaction.userId, model);
    return model;
  }

  @override
  Future<FinanceTransaction> updateTransaction(FinanceTransaction transaction) async {
    final model = FinanceTransactionModel.fromEntity(transaction);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.updateTransaction(model);
    }

    _syncToRemote(transaction.userId, model);
    return model;
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final existing = _memoryCache[transactionId];
    _memoryCache.remove(transactionId);

    if (!kIsWeb) {
      await _localDataSource.deleteTransaction(transactionId);
    }

    if (existing != null) {
      _deleteFromRemote(existing.userId, transactionId);
    }
  }
}
