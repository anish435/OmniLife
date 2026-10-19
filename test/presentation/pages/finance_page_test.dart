import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/core/services/receipt_uploader.dart';
import 'package:omnilife/core/services/report_sharer.dart';
import 'package:omnilife/data/repositories/budget_repository.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/finance_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/finance_controller.dart';
import 'package:omnilife/presentation/pages/finance/finance_page.dart';

import '../controllers/task_controller_test.dart' show FakeAuthRepository;

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
  Future<void> deleteTransaction(String id) async {}
}

class _Sharer implements ReportSharer {
  final names = <String>[];
  @override
  Future<void> sharePdf(Uint8List bytes, String filename) async =>
      names.add(filename);
}

class _Uploader implements ReceiptUploader {
  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async => 'x';
}

FinanceTransaction _tx(
  String id,
  double amount,
  TransactionCategory c, {
  bool income = false,
}) {
  final now = DateTime.now();
  return FinanceTransaction(
    id: id,
    userId: 'u1',
    amount: amount,
    title: 'Item $id',
    category: c,
    date: now,
    isIncome: income,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _Repo repo;
  late _Sharer sharer;
  late FinanceController controller;

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    repo = _Repo()
      ..all.addAll([
        _tx('rent', 900, TransactionCategory.utilities),
        _tx('lunch', 130, TransactionCategory.food),
        _tx('pay', 3000, TransactionCategory.income, income: true),
      ]);
    sharer = _Sharer();
    final auth = AuthController(
      authRepository: FakeAuthRepository(const AppUser(uid: 'u1')),
    )..currentUser.value = const AppUser(uid: 'u1');
    Get.put<AuthController>(auth);
    controller = FinanceController(
      repository: repo,
      authController: auth,
      budgetRepository: BudgetRepository(store: InMemoryBudgetStore()),
      sharer: sharer,
      receiptUploader: _Uploader(),
    );
    Get.put<FinanceController>(controller);
    await controller.saveBudgets({
      TransactionCategory.food: 100,
      TransactionCategory.utilities: 1200,
    });
    await controller.loadTransactions();
  });

  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const FinancePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows the category chart and the monthly chart at 375px', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(PieChart), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(BarChart),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says in words when a category is over budget', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(
      find.text('BUDGETS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(r'Over budget by $30.00'), findsOneWidget);
    expect(
      find.text('You are over budget on food this month.'),
      findsOneWidget,
    );
    expect(find.text(r'$300.00 left'), findsOneWidget);
  });

  testWidgets('budgets can be edited and are saved', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Change budgets'));
    await tester.pumpAndSettle();

    expect(find.text('Monthly budgets'), findsOneWidget);
    final foodField = find.widgetWithText(TextField, 'Food');
    expect(foodField, findsOneWidget);
    await tester.enterText(foodField, '200');
    await tester.tap(find.text('Save budgets'));
    await tester.pumpAndSettle();

    expect(controller.budgets[TransactionCategory.food], 200);
    expect(find.text('Monthly budgets'), findsNothing);
  });

  testWidgets('a bad amount is explained and nothing is saved', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Change budgets'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Food'), 'lots');
    await tester.tap(find.text('Save budgets'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount like 150'), findsOneWidget);
    expect(controller.budgets[TransactionCategory.food], 100);
  });

  testWidgets('the PDF button shares the monthly report', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Share monthly report (PDF)'));
    await tester.pumpAndSettle();
    expect(sharer.names.single, endsWith('.pdf'));
    expect(find.text('Your report is ready.'), findsOneWidget);
  });
}
