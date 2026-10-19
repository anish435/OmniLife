import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/repositories/budget_repository.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/services/finance_math.dart';

/// Builds the monthly finance report as a PDF: a summary, spending against
/// each budget in plain words, and the full transaction list. The same
/// bytes work on web (download) and Android (share sheet).
Future<Uint8List> buildFinanceReportPdf({
  required DateTime month,
  required List<FinanceTransaction> transactions,
  required Budgets budgets,
}) async {
  const ink = PdfColor.fromInt(0xFF1C1B18);
  const muted = PdfColor.fromInt(0xFF6A675F);
  const accent = PdfColor.fromInt(0xFFC9553D);
  const paper = PdfColor.fromInt(0xFFF6F3EE);

  String money(double v) => '\$${v.toStringAsFixed(2)}';
  String label(TransactionCategory c) =>
      c.name[0].toUpperCase() + c.name.substring(1);

  final income = transactions
      .where((t) => t.isIncome)
      .fold<double>(0, (a, t) => a + t.amount);
  final expense = transactions
      .where((t) => !t.isIncome)
      .fold<double>(0, (a, t) => a + t.amount);
  final net = income - expense;
  final spend = spendByCategory(transactions);
  final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));

  pw.TextStyle style(double size, {bool bold = false, PdfColor color = ink}) =>
      pw.TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );

  final doc = pw.Document(title: 'OmniLife finance report', author: 'OmniLife');

  doc.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(
        margin: pw.EdgeInsets.all(40),
        pageFormat: PdfPageFormat.a4,
      ),
      build: (context) => [
        pw.Text('Finance report', style: style(24, bold: true, color: accent)),
        pw.SizedBox(height: 4),
        pw.Text(
          DateFormat('MMMM yyyy').format(month),
          style: style(13, color: muted),
        ),
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          color: paper,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summary('Income', money(income), style),
              _summary('Spent', money(expense), style),
              _summary(
                net < 0 ? 'Over by' : 'Left over',
                money(net.abs()),
                style,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Spending by category', style: style(15, bold: true)),
        pw.SizedBox(height: 8),
        if (spend.isEmpty)
          pw.Text('No spending recorded this month.', style: style(11))
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Category', 'Spent', 'Share', 'Budget'],
            data: [
              for (final s in spend)
                [
                  label(s.category),
                  money(s.amount),
                  '${(s.share * 100).toStringAsFixed(0)}%',
                  BudgetStatus(
                    category: s.category,
                    spent: s.amount,
                    limit: budgets[s.category] ?? 0,
                  ).message,
                ],
            ],
            headerStyle: style(10, bold: true),
            cellStyle: style(10),
            headerDecoration: const pw.BoxDecoration(color: paper),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
        pw.SizedBox(height: 20),
        pw.Text('Transactions', style: style(15, bold: true)),
        pw.SizedBox(height: 8),
        if (sorted.isEmpty)
          pw.Text('Nothing recorded this month.', style: style(11))
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'What', 'Category', 'Amount'],
            data: [
              for (final t in sorted)
                [
                  DateFormat('MMM d').format(t.date),
                  t.title,
                  t.isIncome ? 'Income' : label(t.category),
                  '${t.isIncome ? '+' : '-'}${money(t.amount)}',
                ],
            ],
            headerStyle: style(10, bold: true),
            cellStyle: style(10),
            headerDecoration: const pw.BoxDecoration(color: paper),
            cellAlignments: {3: pw.Alignment.centerRight},
          ),
      ],
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: style(9, color: muted),
        ),
      ),
    ),
  );

  return doc.save();
}

pw.Widget _summary(
  String title,
  String value,
  pw.TextStyle Function(double, {bool bold, PdfColor color}) style,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: style(10, color: const PdfColor.fromInt(0xFF6A675F)),
      ),
      pw.SizedBox(height: 2),
      pw.Text(value, style: style(16, bold: true)),
    ],
  );
}
