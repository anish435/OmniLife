import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:omnilife/core/errors/user_messages.dart';
import 'package:omnilife/core/services/receipt_uploader.dart';
import 'package:omnilife/core/services/report_sharer.dart';
import 'package:omnilife/data/repositories/budget_repository.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/finance_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/finance_controller.dart';

import 'task_controller_test.dart' show FakeAuthRepository;

class _Repo implements FinanceRepository {
  final all = <FinanceTransaction>[];

  @override
  Future<List<FinanceTransaction>> getTransactions(
    String userId, {
    int? month,
    int? year,
  }) async => all
      .where(
        (t) =>
            t.userId == userId &&
            (month == null || (t.date.month == month && t.date.year == year)),
      )
      .toList();

  @override
  Future<FinanceTransaction> createTransaction(FinanceTransaction t) async {
    all.add(t);
    return t;
  }

  @override
  Future<FinanceTransaction> updateTransaction(FinanceTransaction t) async => t;

  @override
  Future<void> deleteTransaction(String id) async =>
      all.removeWhere((t) => t.id == id);
}

class _Sharer implements ReportSharer {
  final shared = <(String, int)>[];
  bool fail = false;

  @override
  Future<void> sharePdf(Uint8List bytes, String filename) async {
    if (fail) throw StateError('no share target');
    shared.add((filename, bytes.length));
  }
}

class _Uploader implements ReceiptUploader {
  final uploads = <(String, String, int)>[];
  bool fail = false;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (fail) throw StateError('offline');
    uploads.add((path, contentType, bytes.length));
    return 'https://example.test/$path';
  }
}

FinanceTransaction _tx(String id, double amount, TransactionCategory c) {
  final now = DateTime.now();
  return FinanceTransaction(
    id: id,
    userId: 'u1',
    amount: amount,
    title: id,
    category: c,
    date: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _Repo repo;
  late _Sharer sharer;
  late _Uploader uploader;
  late InMemoryBudgetStore store;
  late AuthController auth;

  FinanceController build({bool signedIn = true}) {
    Get.testMode = true;
    Get.reset();
    repo = _Repo();
    sharer = _Sharer();
    uploader = _Uploader();
    store = InMemoryBudgetStore();
    auth = AuthController(
      authRepository: FakeAuthRepository(
        signedIn ? const AppUser(uid: 'u1') : null,
      ),
    );
    if (signedIn) auth.currentUser.value = const AppUser(uid: 'u1');
    return FinanceController(
      repository: repo,
      authController: auth,
      budgetRepository: BudgetRepository(store: store),
      sharer: sharer,
      receiptUploader: uploader,
    );
  }

  tearDown(Get.reset);

  group('budgets', () {
    test('start as suggestions but are replaced by saved ones', () async {
      var c = build();
      expect(c.budgets[TransactionCategory.food], 500);
      await c.saveBudgets({TransactionCategory.food: 120});
      expect(c.budgets, {TransactionCategory.food: 120});

      // A fresh controller (new session) reads what was saved, not the
      // hard-coded suggestions.
      expect(await store.load('u1'), {TransactionCategory.food: 120});
      final again = FinanceController(
        repository: repo,
        authController: auth,
        budgetRepository: BudgetRepository(store: store),
        sharer: sharer,
        receiptUploader: uploader,
      );
      await again.loadBudgets();
      expect(again.budgets, {TransactionCategory.food: 120});
      c = again;
      expect(c.budgetStatuses.single.category, TransactionCategory.food);
    });

    test('zero or negative limits mean no budget', () async {
      final c = build();
      await c.saveBudgets({
        TransactionCategory.food: 0,
        TransactionCategory.health: 50,
        TransactionCategory.income: 999,
      });
      expect(c.budgets, {TransactionCategory.health: 50});
    });

    test('signed out says to sign in and changes nothing', () async {
      final c = build(signedIn: false);
      final before = Map.of(c.budgets);
      expect(await c.saveBudgets({TransactionCategory.food: 1}), isFalse);
      expect(c.errorMessage.value, signInToSaveMessage);
      expect(c.budgets, before);
    });

    test('going over a budget is reported in plain words', () async {
      final c = build();
      await c.saveBudgets({TransactionCategory.food: 100});
      repo.all.add(_tx('lunch', 130, TransactionCategory.food));
      await c.loadTransactions();

      expect(c.overBudget.single.category, TransactionCategory.food);
      expect(c.overBudget.single.message, r'Over budget by $30.00');
    });

    test('spending in a category with no budget is still listed', () async {
      final c = build();
      await c.saveBudgets({TransactionCategory.food: 100});
      repo.all.add(_tx('film', 12, TransactionCategory.entertainment));
      await c.loadTransactions();
      final s = c.budgetStatuses.firstWhere(
        (s) => s.category == TransactionCategory.entertainment,
      );
      expect(s.hasBudget, isFalse);
      expect(s.message, 'No budget set');
    });
  });

  group('trend', () {
    test('loads six months of income vs spending', () async {
      final c = build();
      repo.all.add(_tx('a', 20, TransactionCategory.food));
      await c.loadTransactions();
      expect(c.monthlyTrend, hasLength(6));
      expect(c.monthlyTrend.last.expense, 20);
    });
  });

  group('PDF export', () {
    test('builds the report and hands it to the sharer', () async {
      final c = build();
      repo.all.add(_tx('a', 20, TransactionCategory.food));
      await c.loadTransactions();

      expect(await c.exportToPdf(), isTrue);
      expect(sharer.shared, hasLength(1));
      expect(sharer.shared.single.$1, startsWith('omnilife_finance_'));
      expect(sharer.shared.single.$1, endsWith('.pdf'));
      expect(sharer.shared.single.$2, greaterThan(500));
      expect(c.notice.value, 'Your report is ready.');
      expect(c.isExporting.value, isFalse);
    });

    test('a sharing failure is reported plainly', () async {
      final c = build();
      sharer.fail = true;
      expect(await c.exportToPdf(), isFalse);
      expect(c.notice.value, 'Could not make the report. Please try again.');
      expect(c.isExporting.value, isFalse);
    });
  });

  group('receipt upload', () {
    XFile file(String name, int bytes, {String? mime}) =>
        XFile.fromData(Uint8List(bytes), name: name, path: name, mimeType: mime);

    test(
      'uploads to the signed-in users receipts folder with a type',
      () async {
        final c = build();
        final url = await c.uploadReceipt(file('lunch.jpg', 100));
        expect(url, isNotNull);
        final (path, type, size) = uploader.uploads.single;
        expect(path, startsWith('receipts/u1/'));
        expect(path, endsWith('_lunch.jpg'));
        expect(type, 'image/jpeg');
        expect(size, 100);
      },
    );

    test('rejects files that are not photos or PDFs', () async {
      final c = build();
      expect(await c.uploadReceipt(file('notes.txt', 10)), isNull);
      expect(c.errorMessage.value, 'Receipts can be photos or PDF files.');
      expect(uploader.uploads, isEmpty);
    });

    test('rejects files over 10 MB', () async {
      final c = build();
      expect(
        await c.uploadReceipt(file('big.png', maxReceiptBytes + 1)),
        isNull,
      );
      expect(c.errorMessage.value, contains('10 MB'));
      expect(uploader.uploads, isEmpty);
    });

    test('a failed upload gives a friendly message', () async {
      final c = build();
      uploader.fail = true;
      expect(await c.uploadReceipt(file('a.png', 10)), isNull);
      expect(c.errorMessage.value, contains('Could not upload the receipt'));
      expect(c.errorMessage.value, isNot(contains('StateError')));
    });

    test('signed out says to sign in', () async {
      final c = build(signedIn: false);
      expect(await c.uploadReceipt(file('a.png', 10)), isNull);
      expect(c.errorMessage.value, signInToSaveMessage);
    });
  });

  test('adding a transaction while signed out says to sign in', () async {
    final c = build(signedIn: false);
    final created = await c.addTransaction(
      amount: 5,
      title: 'x',
      category: TransactionCategory.food,
      date: DateTime.now(),
      isIncome: false,
    );
    expect(created, isNull);
    expect(c.errorMessage.value, signInToSaveMessage);
  });
}
