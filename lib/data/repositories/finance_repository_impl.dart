// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../../core/sync/repository_sync.dart';
import '../../core/sync/sync_engine.dart';
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
    SyncEngine? syncEngine,
  }) : _localDataSource = localDataSource ?? LocalFinanceDataSource(),
       _remoteDataSource = remoteDataSource ?? UserScopedFirestoreDataSource(),
       _syncEngine = syncEngine;

  final LocalFinanceDataSource _localDataSource;
  final UserScopedFirestoreDataSource _remoteDataSource;
  final SyncEngine? _syncEngine;

  /// Durable, retried uploads through the shared [SyncEngine].
  late final RepositorySync _sync = RepositorySync(
    engine: _syncEngine,
    fallbackSet: (u, c, i, d) => _remoteDataSource.set(u, c, i, d),
    fallbackDelete: (u, c, i) => _remoteDataSource.delete(u, c, i),
  );

  final Map<String, FinanceTransactionModel> _memoryCache = {};

  Future<void> _syncToRemote(
    String userId,
    FinanceTransactionModel model,
  ) async {
    await _sync.set(
      userId,
      FirestoreCollections.expenses,
      model.id,
      model.toFirestoreMap(),
      updatedAt: model.updatedAt,
    );
  }

  Future<void> _deleteFromRemote(String userId, String id) async {
    await _sync.delete(userId, FirestoreCollections.expenses, id);
  }

  @override
  Future<List<FinanceTransaction>> getTransactions(
    String userId, {
    int? month,
    int? year,
  }) async {
    if (kIsWeb) {
      try {
        // Layer writes that have not uploaded yet over the server copy.
        final docs = await _sync.overlay(
          userId,
          FirestoreCollections.expenses,
          await _remoteDataSource.list(userId, FirestoreCollections.expenses),
        );
        var transactions = docs.map(FinanceTransactionModel.fromMap).toList();
        if (month != null && year != null) {
          transactions = transactions
              .where((e) => e.date.year == year && e.date.month == month)
              .toList();
        }
        transactions.sort((a, b) => b.date.compareTo(a.date));
        for (final e in transactions) {
          _memoryCache[e.id] = e;
        }
        return transactions;
      } catch (_) {
        var filtered = _memoryCache.values.where((e) => e.userId == userId);
        if (month != null && year != null) {
          filtered = filtered.where(
            (e) => e.date.year == year && e.date.month == month,
          );
        }
        final list = filtered.toList()..sort((a, b) => b.date.compareTo(a.date));
        return list;
      }
    }

    final localTxs = await _localDataSource.getTransactions(
      userId,
      month: month,
      year: year,
    );
    for (final e in localTxs) {
      _memoryCache[e.id] = e;
    }
    return localTxs;
  }

  @override
  Future<FinanceTransaction> createTransaction(
    FinanceTransaction transaction,
  ) async {
    final model = FinanceTransactionModel.fromEntity(transaction);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.insertTransaction(model);
    }

    await _syncToRemote(transaction.userId, model);
    return model;
  }

  @override
  Future<FinanceTransaction> updateTransaction(
    FinanceTransaction transaction,
  ) async {
    final model = FinanceTransactionModel.fromEntity(transaction);
    _memoryCache[model.id] = model;

    if (!kIsWeb) {
      await _localDataSource.updateTransaction(model);
    }

    await _syncToRemote(transaction.userId, model);
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
      await _deleteFromRemote(existing.userId, transactionId);
    }
  }
}
