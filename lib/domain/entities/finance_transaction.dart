import 'package:equatable/equatable.dart';

enum TransactionCategory {
  income,
  food,
  transport,
  utilities,
  entertainment,
  shopping,
  health,
  other
}

class FinanceTransaction extends Equatable {
  const FinanceTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.title,
    this.category = TransactionCategory.other,
    required this.date,
    this.isIncome = false,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final double amount; // Absolute value. isIncome determines if it's positive or negative cashflow.
  final String title;
  final TransactionCategory category;
  final DateTime date;
  final bool isIncome;
  final String? receiptUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceTransaction copyWith({
    String? id,
    String? userId,
    double? amount,
    String? title,
    TransactionCategory? category,
    DateTime? date,
    bool? isIncome,
    String? receiptUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      isIncome: isIncome ?? this.isIncome,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        amount,
        title,
        category,
        date,
        isIncome,
        receiptUrl,
        createdAt,
        updatedAt,
      ];
}
