import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/data/repositories/budget_repository.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';
import 'package:omnilife/domain/insights/finance_advice_service.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/finance_controller.dart';
import 'package:omnilife/presentation/pages/finance/finance_page.dart';
import 'package:omnilife/presentation/pages/finance/finance_suggestions_sheet.dart';

import '../../support/assistant_fakes.dart' show FakeFinanceRepository;
import '../controllers/task_controller_test.dart' show FakeAuthRepository;

class _Provider implements AiProvider, TextCompleter {
  _Provider(this.reply, {this.configured = true});
  final String? reply;
  final bool configured;
  var calls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    required List<AiToolSpec> tools,
  }) async => const AiResponse();

  @override
  Future<String?> complete({
    required List<AiMessage> messages,
    int maxTokens = 400,
  }) async {
    calls++;
    return reply;
  }
}

const _written = '''
Where it's going
- Shopping is most of the month, about 3,200 of 4,100.
Worth a look
- That one big purchase stands out against everything else.
Things you could do
- Aim to trim shopping by roughly 300 next month.
Income and spending
- You kept 59% of your income this month.
On holdings and investing, in general
- Emergency fund first, then broad index funds, and always check fees.
''';

FinanceTransaction _tx(
  String id,
  double amount,
  TransactionCategory c,
  DateTime date, {
  bool income = false,
}) => FinanceTransaction(
  id: id,
  userId: 'u1',
  amount: amount,
  title: 'Item $id',
  category: c,
  date: date,
  isIncome: income,
  createdAt: date,
  updatedAt: date,
);

void main() {
  late FakeFinanceRepository repo;
  late FinanceController controller;
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 10);
  final lastMonth = DateTime(now.year, now.month - 1, 10);

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    repo = FakeFinanceRepository();
    for (final t in [
      _tx('a', 3200, TransactionCategory.shopping, thisMonth),
      _tx('b', 900, TransactionCategory.food, thisMonth),
      _tx('c', 10000, TransactionCategory.income, thisMonth, income: true),
      _tx('d', 2000, TransactionCategory.shopping, lastMonth),
    ]) {
      repo.store[t.id] = t;
    }
    final auth = AuthController(
      authRepository: FakeAuthRepository(const AppUser(uid: 'u1')),
    )..currentUser.value = const AppUser(uid: 'u1');
    Get.put<AuthController>(auth);
    controller = FinanceController(
      repository: repo,
      authController: auth,
      budgetRepository: BudgetRepository(store: InMemoryBudgetStore()),
    );
    Get.put<FinanceController>(controller);
    await controller.loadTransactions();
  });

  tearDown(Get.reset);

  Future<void> openSheet(
    WidgetTester tester, {
    FinanceAdviceService? service,
    double width = 375,
  }) async {
    tester.view.physicalSize = Size(width, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => FinanceSuggestionsSheet.show(
                  context,
                  controller: controller,
                  service: service,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('works with no key: rule-based tips, no overflow at 375px', (
    tester,
  ) async {
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('WHERE IT\'S GOING'), findsOneWidget);
    expect(find.textContaining('Shopping: 3,200'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('General guidance, not financial advice.'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('General guidance, not financial advice.'),
      findsOneWidget,
    );
    expect(find.textContaining('index funds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unconfigured provider behaves the same as no provider', (
    tester,
  ) async {
    final p = _Provider(_written, configured: false);
    await openSheet(tester, service: FinanceAdviceService(provider: () => p));
    expect(find.textContaining('Shopping: 3,200'), findsOneWidget);
    expect(p.calls, 0);
  });

  testWidgets('with a key, the written version replaces the tips (one call)', (
    tester,
  ) async {
    final p = _Provider(_written);
    await openSheet(tester, service: FinanceAdviceService(provider: () => p));
    await tester.pump(const Duration(milliseconds: 200));
    expect(p.calls, 1);
    expect(
      find.textContaining('Shopping is most of the month'),
      findsOneWidget,
    );
    expect(find.textContaining('Shopping: 3,200'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unusable written reply keeps the rule-based tips', (
    tester,
  ) async {
    final p = _Provider('buy a hot stock, guaranteed to double');
    await openSheet(tester, service: FinanceAdviceService(provider: () => p));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Shopping: 3,200'), findsOneWidget);
  });

  testWidgets('an empty month still offers something', (tester) async {
    repo.store.clear();
    await controller.loadTransactions();
    await openSheet(tester);
    expect(find.textContaining('Nothing to go on'), findsOneWidget);
    expect(find.textContaining('index funds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Finance page has a plain Suggestions action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const FinancePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Suggestions'), findsOneWidget);

    await tester.tap(find.text('Suggestions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Shopping: 3,200'), findsOneWidget);
  });
}
