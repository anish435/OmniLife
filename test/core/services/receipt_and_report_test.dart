import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/finance_report_pdf.dart';
import 'package:omnilife/core/services/receipt_uploader.dart';
import 'package:omnilife/data/repositories/budget_repository.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';

void main() {
  group('receipt storage path', () {
    test('lives in the per-user folder storage.rules allows', () {
      final path = receiptStoragePath('u1', 'abc', 'lunch.jpg');
      expect(path, 'receipts/u1/abc_lunch.jpg');
      expect(path.startsWith('receipts/u1/'), isTrue);
    });

    test('a hostile file name cannot leave the folder', () {
      final path = receiptStoragePath('u1', 'abc', '../../u2/steal me.png');
      expect(path, 'receipts/u1/abc_steal_me.png');
      expect(path.split('/'), hasLength(3));
    });

    test('an empty name still gets a usable one', () {
      expect(receiptStoragePath('u1', 'abc', ''), 'receipts/u1/abc_receipt');
    });
  });

  group('receipt content type', () {
    test('accepts images and pdf by name', () {
      expect(receiptContentType('a.JPG'), 'image/jpeg');
      expect(receiptContentType('a.png'), 'image/png');
      expect(receiptContentType('a.pdf'), 'application/pdf');
    });

    test('trusts a reported image type', () {
      expect(receiptContentType('scan', reported: 'image/heic'), 'image/heic');
    });

    test('rejects anything else', () {
      expect(receiptContentType('notes.txt'), isNull);
      expect(receiptContentType('noextension'), isNull);
      expect(receiptContentType('a.exe', reported: 'application/zip'), isNull);
    });
  });

  group('PDF report', () {
    FinanceTransaction tx(
      String id,
      double amount,
      TransactionCategory c, {
      bool income = false,
    }) => FinanceTransaction(
      id: id,
      userId: 'u1',
      amount: amount,
      title: 'Item $id',
      category: c,
      date: DateTime(2026, 3, 4),
      isIncome: income,
      createdAt: DateTime(2026, 3, 4),
      updatedAt: DateTime(2026, 3, 4),
    );

    test('builds a real PDF document', () async {
      final bytes = await buildFinanceReportPdf(
        month: DateTime(2026, 3, 1),
        transactions: [
          tx('a', 650, TransactionCategory.food),
          tx('pay', 2000, TransactionCategory.income, income: true),
        ],
        budgets: {TransactionCategory.food: 500},
      );
      expect(bytes.length, greaterThan(500));
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('also works for an empty month', () async {
      final bytes = await buildFinanceReportPdf(
        month: DateTime(2026, 3, 1),
        transactions: const [],
        budgets: defaultBudgets,
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
