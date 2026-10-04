import '../../domain/entities/finance_transaction.dart';

class FinanceTransactionModel extends FinanceTransaction {
  const FinanceTransactionModel({
    required super.id,
    required super.userId,
    required super.amount,
    required super.title,
    super.category,
    required super.date,
    super.isIncome,
    super.receiptUrl,
    required super.createdAt,
    required super.updatedAt,
  });

  factory FinanceTransactionModel.fromEntity(FinanceTransaction transaction) {
    return FinanceTransactionModel(
      id: transaction.id,
      userId: transaction.userId,
      amount: transaction.amount,
      title: transaction.title,
      category: transaction.category,
      date: transaction.date,
      isIncome: transaction.isIncome,
      receiptUrl: transaction.receiptUrl,
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
    );
  }

  factory FinanceTransactionModel.fromMap(Map<String, Object?> map) {
    DateTime parseDate(Object? val, DateTime fallback) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final catStr = (map['category'] as String?) ?? 'other';
    final category = TransactionCategory.values.firstWhere(
      (e) => e.name == catStr,
      orElse: () => TransactionCategory.other,
    );

    final now = DateTime.now();

    return FinanceTransactionModel(
      id: (map['id'] ?? '') as String,
      userId: ((map['user_id'] ?? map['userId']) ?? '') as String,
      amount: ((map['amount'] ?? 0) as num).toDouble(),
      title: (map['title'] ?? '') as String,
      category: category,
      date: parseDate(map['date'], now),
      isIncome: (map['is_income'] ?? map['isIncome'] ?? 0) == 1 || (map['is_income'] ?? map['isIncome']) == true,
      receiptUrl: map['receipt_url'] as String?,
      createdAt: parseDate(map['created_at'] ?? map['createdAt'], now),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt'], now),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'title': title,
      'category': category.name,
      'date': date.millisecondsSinceEpoch,
      'is_income': isIncome ? 1 : 0,
      'receipt_url': receiptUrl,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'amount': amount,
      'title': title,
      'category': category.name,
      'date': date.toIso8601String(),
      'isIncome': isIncome,
      'receiptUrl': receiptUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
