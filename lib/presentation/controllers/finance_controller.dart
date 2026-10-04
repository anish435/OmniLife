import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/repositories/finance_repository.dart';
import 'auth_controller.dart';

class FinanceController extends GetxController {
  final _financeRepository = Get.find<FinanceRepository>();
  final _authController = Get.find<AuthController>();

  final transactions = <FinanceTransaction>[].obs;
  final currentMonth = DateTime.now().obs;

  final isLoading = false.obs;
  final errorMessage = Rx<String?>(null);

  // Hardcoded category budgets for demonstration
  final budgets = <TransactionCategory, double>{
    TransactionCategory.food: 500,
    TransactionCategory.transport: 200,
    TransactionCategory.utilities: 300,
    TransactionCategory.entertainment: 150,
    TransactionCategory.shopping: 250,
    TransactionCategory.health: 100,
    TransactionCategory.other: 100,
  }.obs;

  String get _currentUserId => _authController.currentUser.value?.uid ?? '';

  double get totalIncome {
    return transactions.where((e) => e.isIncome).fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalExpense {
    return transactions.where((e) => !e.isIncome).fold(0.0, (sum, e) => sum + e.amount);
  }

  double get balance => totalIncome - totalExpense;

  Map<TransactionCategory, double> get expensesByCategory {
    final map = <TransactionCategory, double>{};
    for (final e in transactions.where((e) => !e.isIncome)) {
      map[e.category] = (map[e.category] ?? 0.0) + e.amount;
    }
    return map;
  }

  @override
  void onInit() {
    super.onInit();
    ever(_authController.currentUser, (_) => loadTransactions());
    ever(currentMonth, (_) => loadTransactions());
    if (_authController.currentUser.value != null) {
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
    } catch (e) {
      errorMessage.value = 'Failed to load transactions: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> uploadReceipt(XFile file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child(_currentUserId)
          .child('\${Uuid().v4()}_\${file.name}');
      
      final data = await file.readAsBytes();
      final uploadTask = ref.putData(data);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      errorMessage.value = 'Failed to upload receipt: \$e';
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
    if (_currentUserId.isEmpty) return null;

    final now = DateTime.now();
    final newTransaction = FinanceTransaction(
      id: Uuid().v4(),
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

    final isCurrentView = date.year == currentMonth.value.year && date.month == currentMonth.value.month;
    if (isCurrentView) {
      transactions.add(newTransaction);
      transactions.sort((a, b) => b.date.compareTo(a.date));
    }

    try {
      final created = await _financeRepository.createTransaction(newTransaction);
      if (isCurrentView) {
        final idx = transactions.indexWhere((e) => e.id == newTransaction.id);
        if (idx != -1) {
          transactions[idx] = created;
        }
      }
      return created;
    } catch (e) {
      if (isCurrentView) {
        transactions.removeWhere((e) => e.id == newTransaction.id);
      }
      errorMessage.value = 'Failed to create transaction: $e';
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
      return true;
    } catch (e) {
      transactions.insert(existingIdx, existing);
      errorMessage.value = 'Failed to delete transaction: $e';
      return false;
    }
  }

  Future<void> exportToCsv() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln("Date,Title,Amount,Category,Type");
      
      for (var tx in transactions) {
        final date = tx.date.toIso8601String();
        // Escape quotes and wrap in quotes if there's a comma
        final title = tx.title.contains(',') ? '"${tx.title.replaceAll('"', '""')}"' : tx.title;
        final amount = tx.amount.toString();
        final category = tx.category.name;
        final type = tx.isIncome ? "Income" : "Expense";
        buffer.writeln("$date,$title,$amount,$category,$type");
      }
      
      String csv = buffer.toString();
      
      if (kIsWeb) {
        Get.snackbar("Export Success", "CSV generated. (Web download not fully implemented in this demo)");
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path = "${dir.path}/monthly_report_${currentMonth.value.year}_${currentMonth.value.month}.csv";
        final file = File(path);
        await file.writeAsString(csv);
        Get.snackbar("Export Success", "Saved to $path");
      }
    } catch (e) {
      Get.snackbar("Export Failed", "Error exporting to CSV: $e");
    }
  }
}
