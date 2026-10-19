// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sync/repository_sync.dart';
import '../../core/sync/sync_engine.dart';
import '../../domain/entities/finance_transaction.dart';
import '../datasources/remote/user_scoped_firestore_datasource.dart';

/// Monthly spending limit per category.
typedef Budgets = Map<TransactionCategory, double>;

/// Starting suggestions shown until the person sets their own. They are
/// never written anywhere on their own.
const Budgets defaultBudgets = {
  TransactionCategory.food: 500,
  TransactionCategory.transport: 200,
  TransactionCategory.utilities: 300,
  TransactionCategory.entertainment: 150,
  TransactionCategory.shopping: 250,
  TransactionCategory.health: 100,
  TransactionCategory.other: 100,
};

/// Where per-category budgets are stored on the device.
abstract class BudgetStore {
  Future<Budgets?> load(String uid);
  Future<void> save(String uid, Budgets budgets);
}

class InMemoryBudgetStore implements BudgetStore {
  final _data = <String, Budgets>{};

  @override
  Future<Budgets?> load(String uid) async {
    final b = _data[uid];
    return b == null ? null : Map.of(b);
  }

  @override
  Future<void> save(String uid, Budgets budgets) async =>
      _data[uid] = Map.of(budgets);
}

class SharedPrefsBudgetStore implements BudgetStore {
  static String _key(String uid) => 'finance_budgets_$uid';

  @override
  Future<Budgets?> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null) return null;
    return BudgetRepository.decode(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(String uid, Budgets budgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(uid),
      jsonEncode(BudgetRepository.encode(budgets)),
    );
  }
}

/// Loads and saves budgets. They are kept on the device first, and also
/// queued for the cloud at `users/{uid}/settings/budgets` through the sync
/// engine so they follow the person to another device.
class BudgetRepository {
  BudgetRepository({
    BudgetStore? store,
    UserScopedFirestoreDataSource? remote,
    SyncEngine? syncEngine,
    DateTime Function()? now,
  }) : _store = store ?? SharedPrefsBudgetStore(),
       _remote = remote,
       _syncEngine = syncEngine,
       _now = now ?? DateTime.now;

  static const collection = 'settings';
  static const docId = 'budgets';

  final BudgetStore _store;
  final UserScopedFirestoreDataSource? _remote;
  final SyncEngine? _syncEngine;
  final DateTime Function() _now;

  late final RepositorySync _sync = RepositorySync(
    engine: _syncEngine,
    fallbackSet: (u, c, i, d) =>
        (_remote ?? UserScopedFirestoreDataSource()).set(u, c, i, d),
    fallbackDelete: (u, c, i) =>
        (_remote ?? UserScopedFirestoreDataSource()).delete(u, c, i),
  );

  static Map<String, dynamic> encode(Budgets budgets) => {
    for (final e in budgets.entries) e.key.name: e.value,
  };

  static Budgets decode(Map<String, dynamic> map) {
    final result = <TransactionCategory, double>{};
    for (final e in map.entries) {
      final category = TransactionCategory.values
          .where((c) => c.name == e.key)
          .firstOrNull;
      final value = e.value;
      if (category == null || value is! num || value < 0) continue;
      result[category] = value.toDouble();
    }
    return result;
  }

  /// The saved budgets for [uid], or null when none were ever saved.
  Future<Budgets?> load(String uid) async {
    final local = await _store.load(uid);
    if (local != null) return local;
    // Nothing on this device yet: look for budgets saved from another one.
    try {
      final doc = await (_remote ?? UserScopedFirestoreDataSource()).get(
        uid,
        collection,
        docId,
      );
      final raw = doc?['budgets'];
      if (raw is Map) {
        final budgets = decode(raw.cast<String, dynamic>());
        if (budgets.isNotEmpty) {
          await _store.save(uid, budgets);
          return budgets;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> save(String uid, Budgets budgets) async {
    await _store.save(uid, budgets);
    final now = _now();
    await _sync.set(uid, collection, docId, {
      'userId': uid,
      'budgets': encode(budgets),
      'updatedAt': now.toIso8601String(),
    }, updatedAt: now);
  }
}
