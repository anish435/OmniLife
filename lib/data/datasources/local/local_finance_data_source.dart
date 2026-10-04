import 'package:sqflite/sqflite.dart';
import '../../models/finance_transaction_model.dart';
import 'app_database.dart';

class LocalFinanceDataSource {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<FinanceTransactionModel>> getTransactions(String userId, {int? month, int? year}) async {
    final db = await _db;
    List<Map<String, Object?>> maps;

    if (month != null && year != null) {
      final start = DateTime(year, month, 1).millisecondsSinceEpoch;
      final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;

      maps = await db.query(
        AppDatabase.financeTable,
        where: 'user_id = ? AND date >= ? AND date < ?',
        whereArgs: [userId, start, end],
        orderBy: 'date DESC',
      );
    } else {
      maps = await db.query(
        AppDatabase.financeTable,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date DESC',
      );
    }

    return maps.map(FinanceTransactionModel.fromMap).toList();
  }

  Future<void> insertTransaction(FinanceTransactionModel transaction) async {
    final db = await _db;
    await db.insert(
      AppDatabase.financeTable,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(FinanceTransactionModel transaction) async {
    final db = await _db;
    await db.update(
      AppDatabase.financeTable,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    final db = await _db;
    await db.delete(
      AppDatabase.financeTable,
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }
}
