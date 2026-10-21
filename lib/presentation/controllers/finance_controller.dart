// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/user_messages.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/finance_report_pdf.dart';
import '../../core/services/receipt_uploader.dart';
import '../../core/services/report_sharer.dart';
import '../../data/repositories/budget_repository.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../domain/services/finance_math.dart';
import 'auth_controller.dart';

class FinanceController extends GetxController {
  FinanceController({
    FinanceRepository? repository,
    AuthController? authController,
    BudgetRepository? budgetRepository,
    ReportSharer? sharer,
    ReceiptUploader? receiptUploader,
  }) : _repositoryOverride = repository,
       _authOverride = authController,
       _budgetRepositoryOverride = budgetRepository,
       _sharer = sharer ?? const PrintingReportSharer(),
       _receiptUploader = receiptUploader ?? const FirebaseReceiptUploader();

  final FinanceRepository? _repositoryOverride;
  final AuthController? _authOverride;
  final BudgetRepository? _budgetRepositoryOverride;
  final ReportSharer _sharer;
  final ReceiptUploader _receiptUploader;

  late final FinanceRepository _financeRepository =
      _repositoryOverride ?? Get.find<FinanceRepository>();
  late final AuthController _authController =
      _authOverride ?? Get.find<AuthController>();
  late final BudgetRepository _budgetRepository =
      _budgetRepositoryOverride ?? BudgetRepository();

  final transactions = <FinanceTransaction>[].obs;
  final currentMonth = DateTime.now().obs;

  final isLoading = false.obs;
  final errorMessage = Rx<String?>(null);

  /// A short message about the last export or budget change, for the page
  /// to show once.
  final notice = Rx<String?>(null);

  /// Monthly limit per category. Starts from suggestions and is replaced by
  /// whatever the person saved (see [saveBudgets]).
  final budgets = <TransactionCategory, double>{...defaultBudgets}.obs;

  /// Income vs spending for the last six months, oldest first.
  final monthlyTrend = <MonthlyTotals>[].obs;

  final isExporting = false.obs;

  String get _currentUserId =>
      _authController.currentUser.value?.uid ?? 'guest-user';

  double get totalIncome {
    return transactions
        .where((e) => e.isIncome)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalExpense {
    return transactions
        .where((e) => !e.isIncome)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get balance => totalIncome - totalExpense;

  Map<TransactionCategory, double> get expensesByCategory {
    final map = <TransactionCategory, double>{};
    for (final e in transactions.where((e) => !e.isIncome)) {
      map[e.category] = (map[e.category] ?? 0.0) + e.amount;
    }
    return map;
  }

  /// Spending slices for the chart, biggest first.
  List<CategorySpend> get categorySpend => spendByCategory(transactions);

  /// Every expense category with its budget and how it is going. A category
  /// with spending but no budget is included so it is not silently ignored.
  List<BudgetStatus> get budgetStatuses {
    final spent = expensesByCategory;
    final categories = <TransactionCategory>{
      ...budgets.keys.where((c) => c != TransactionCategory.income),
      ...spent.keys,
    };
    final list = [
      for (final c in categories)
        BudgetStatus(category: c, spent: spent[c] ?? 0, limit: budgets[c] ?? 0),
    ]..sort((a, b) => a.category.index.compareTo(b.category.index));
    return list;
  }

  /// Categories currently over their budget, for a plain-words banner.
  List<BudgetStatus> get overBudget =>
      budgetStatuses.where((s) => s.isOver).toList();

  @override
  void onInit() {
    super.onInit();
    ever(_authController.currentUser, (_) {
      loadBudgets();
      loadTransactions();
    });
    ever(currentMonth, (_) => loadTransactions());
    if (_authController.currentUser.value != null) {
      loadBudgets();
      loadTransactions();
    }
  }

  void previousMonth() {
    final current = currentMonth.value;
    currentMonth.value = DateTime(current.year, current.month - 1, 1);
  }

  void nextMonth() {
    final current = currentMonth.value;
    currentMonth.value = DateTime(current.year, current.month + 1, 1);
  }

  Future<void> loadTransactions() async {
    if (_currentUserId.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loaded = await _financeRepository.getTransactions(
        _currentUserId,
        month: currentMonth.value.month,
        year: currentMonth.value.year,
      );
      transactions.assignAll(loaded);
    } catch (_) {
      errorMessage.value =
          'Could not load your transactions. Please try again.';
    } finally {
      isLoading.value = false;
    }
    await loadTrend();
  }

  /// Refreshes the six-month income vs spending chart.
  Future<void> loadTrend() async {
    if (_currentUserId.isEmpty) return;
    try {
      final all = await _financeRepository.getTransactions(_currentUserId);
      monthlyTrend.assignAll(monthlyTotals(all, currentMonth.value));
    } catch (_) {
      // The chart is a bonus; the month's list already loaded.
    }
  }

  /// Another month's transactions, for comparisons. Empty when signed out or
  /// when they cannot be read; never throws.
  Future<List<FinanceTransaction>> transactionsForMonth(DateTime month) async {
    if (_currentUserId.isEmpty) return const [];
    try {
      return await _financeRepository.getTransactions(
        _currentUserId,
        month: month.month,
        year: month.year,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> loadBudgets() async {
    final uid = _currentUserId;
    if (uid.isEmpty) return;
    try {
      final saved = await _budgetRepository.load(uid);
      if (saved != null) {
        budgets
          ..clear()
          ..addAll(saved);
      }
    } catch (_) {
      // Keep the suggestions if saved budgets cannot be read.
    }
  }

  /// Saves the person's own monthly limits. A limit of 0 (or less) means
  /// "no budget" for that category.
  Future<bool> saveBudgets(Map<TransactionCategory, double> next) async {
    final uid = _currentUserId;
    if (uid.isEmpty) {
      errorMessage.value = signInToSaveMessage;
      return false;
    }
    final clean = {
      for (final e in next.entries)
        if (e.key != TransactionCategory.income && e.value > 0)
          e.key: double.parse(e.value.toStringAsFixed(2)),
    };
    final previous = Map.of(budgets);
    budgets
      ..clear()
      ..addAll(clean);
    try {
      await _budgetRepository.save(uid, clean);
      notice.value = 'Budgets saved.';
      return true;
    } catch (_) {
      budgets
        ..clear()
        ..addAll(previous);
      errorMessage.value = 'Could not save your budgets. Please try again.';
      return false;
    }
  }

  /// Uploads a receipt photo or PDF to `receipts/{uid}/...` and returns its
  /// download link, or null (with [errorMessage] set) when it could not.
  Future<String?> uploadReceipt(XFile file) async {
    final uid = _currentUserId;
    if (uid.isEmpty) {
      errorMessage.value = signInToSaveMessage;
      return null;
    }
    final contentType = receiptContentType(file.name, reported: file.mimeType);
    if (contentType == null) {
      errorMessage.value = 'Receipts can be photos or PDF files.';
      return null;
    }
    try {
      final data = await file.readAsBytes();
      if (data.length > maxReceiptBytes) {
        errorMessage.value =
            'That file is too big. Receipts can be up to 10 MB.';
        return null;
      }
      return await _receiptUploader.upload(
        path: receiptStoragePath(uid, const Uuid().v4(), file.name),
        bytes: data,
        contentType: contentType,
      );
    } catch (_) {
      errorMessage.value =
          'Could not upload the receipt. Check your connection and try again.';
      return null;
    }
  }

  Future<FinanceTransaction?> addTransaction({
    required double amount,
    required String title,
    required TransactionCategory category,
    required DateTime date,
    required bool isIncome,
    String? receiptUrl,
  }) async {
    if (_currentUserId.isEmpty) {
      errorMessage.value = signInToSaveMessage;
      return null;
    }

    final now = DateTime.now();
    final newTransaction = FinanceTransaction(
      id: const Uuid().v4(),
      userId: _currentUserId,
      amount: amount,
      title: title,
      category: category,
      date: date,
      isIncome: isIncome,
      receiptUrl: receiptUrl,
      createdAt: now,
      updatedAt: now,
    );

    final isCurrentView =
        date.year == currentMonth.value.year &&
        date.month == currentMonth.value.month;
    if (isCurrentView) {
      transactions.add(newTransaction);
      transactions.sort((a, b) => b.date.compareTo(a.date));
    }

    try {
      final created = await _financeRepository.createTransaction(
        newTransaction,
      );
      if (isCurrentView) {
        final idx = transactions.indexWhere((e) => e.id == newTransaction.id);
        if (idx != -1) {
          transactions[idx] = created;
        }
      }
      AnalyticsService.instance.logEvent(AnalyticsEvents.transactionAdded, {
        'kind': isIncome ? 'income' : 'expense',
      });
      unawaited(loadTrend());
      return created;
    } catch (_) {
      if (isCurrentView) {
        transactions.removeWhere((e) => e.id == newTransaction.id);
      }
      errorMessage.value = 'That did not save. Please try again.';
      return null;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    final existingIdx = transactions.indexWhere((e) => e.id == id);
    if (existingIdx == -1) return false;

    final existing = transactions[existingIdx];
    transactions.removeAt(existingIdx);

    try {
      await _financeRepository.deleteTransaction(id);
      unawaited(loadTrend());
      return true;
    } catch (_) {
      transactions.insert(existingIdx, existing);
      errorMessage.value = 'Could not delete that. Please try again.';
      return false;
    }
  }

  /// Builds this month's PDF report and hands it over: a download on web,
  /// the share sheet on Android. Returns true when it was handed over.
  Future<bool> exportToPdf() async {
    if (isExporting.value) return false;
    isExporting.value = true;
    try {
      final month = currentMonth.value;
      final bytes = await buildFinanceReportPdf(
        month: month,
        transactions: List.of(transactions),
        budgets: Map.of(budgets),
      );
      final name =
          'omnilife_finance_${DateFormat('yyyy_MM').format(month)}.pdf';
      await _sharer.sharePdf(bytes, name);
      notice.value = 'Your report is ready.';
      return true;
    } catch (_) {
      notice.value = 'Could not make the report. Please try again.';
      return false;
    } finally {
      isExporting.value = false;
    }
  }

  Future<void> exportToCsv() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln("Date,Title,Amount,Category,Type");

      for (var tx in transactions) {
        final date = tx.date.toIso8601String();
        // Escape quotes and wrap in quotes if there's a comma
        final title = tx.title.contains(',')
            ? '"${tx.title.replaceAll('"', '""')}"'
            : tx.title;
        final amount = tx.amount.toString();
        final category = tx.category.name;
        final type = tx.isIncome ? "Income" : "Expense";
        buffer.writeln("$date,$title,$amount,$category,$type");
      }

      String csv = buffer.toString();

      if (kIsWeb) {
        Get.snackbar(
          "Spreadsheet not available here",
          "Spreadsheet export is not available in the browser yet. Use the PDF report instead.",
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            "${dir.path}/monthly_report_${currentMonth.value.year}_${currentMonth.value.month}.csv";
        final file = File(path);
        await file.writeAsString(csv);
        Get.snackbar("Spreadsheet saved", "Saved to $path");
      }
    } catch (e) {
      Get.snackbar(
        "Export failed",
        "Could not export the spreadsheet. Please try again.",
      );
    }
  }
}
