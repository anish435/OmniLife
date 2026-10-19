import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/sync/sync_operation.dart';
import 'package:omnilife/data/datasources/remote/user_scoped_firestore_datasource.dart';
import 'package:omnilife/data/repositories/budget_repository.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';

import '../../support/sync_fakes.dart';

class _NoRemote extends UserScopedFirestoreDataSource {
  Map<String, dynamic>? doc;
  var writes = 0;

  @override
  Future<Map<String, dynamic>?> get(
    String uid,
    String collection,
    String docId,
  ) async => doc;

  @override
  Future<void> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    writes++;
  }
}

void main() {
  late TestSync sync;
  late InMemoryBudgetStore store;
  late _NoRemote remote;
  late BudgetRepository repo;

  setUp(() {
    sync = TestSync();
    store = InMemoryBudgetStore();
    remote = _NoRemote();
    repo = BudgetRepository(
      store: store,
      remote: remote,
      syncEngine: sync.engine,
      now: () => DateTime(2026, 3, 1, 8),
    );
  });

  tearDown(() => sync.dispose());

  test('nothing saved means no budgets, not the suggestions', () async {
    expect(await repo.load('u1'), isNull);
  });

  test(
    'save keeps budgets on the device and queues them for the cloud',
    () async {
      await repo.save('u1', {
        TransactionCategory.food: 320,
        TransactionCategory.transport: 75.5,
      });

      final loaded = await repo.load('u1');
      expect(loaded, {
        TransactionCategory.food: 320,
        TransactionCategory.transport: 75.5,
      });

      final op = await sync.op('settings', 'budgets');
      expect(op, isNotNull);
      expect(op!.type, SyncOpType.set);
      expect(op.uid, 'u1');
      expect(op.data!['budgets'], {'food': 320, 'transport': 75.5});
      expect(op.data!['userId'], 'u1');
      expect(remote.writes, 0);
    },
  );

  test('budgets are kept per person', () async {
    await repo.save('u1', {TransactionCategory.food: 100});
    expect(await repo.load('u2'), isNull);
  });

  test('a new device picks budgets up from the cloud copy', () async {
    remote.doc = {
      'budgets': {'health': 60, 'bogus': 5, 'food': -3},
    };
    final loaded = await repo.load('u1');
    expect(loaded, {TransactionCategory.health: 60});
    // Cached locally afterwards.
    remote.doc = null;
    expect(await repo.load('u1'), {TransactionCategory.health: 60});
  });

  test('decode ignores unknown categories and bad values', () {
    expect(BudgetRepository.decode({'food': 10, 'nope': 1, 'other': 'x'}), {
      TransactionCategory.food: 10,
    });
  });
}
