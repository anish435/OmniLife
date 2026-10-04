import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/finance_transaction.dart';
import '../../controllers/finance_controller.dart';
import '../../widgets/app_empty_view.dart';
import 'create_transaction_sheet.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FinanceController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance & Budgeting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: controller.exportToCsv,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CreateTransactionSheet.show(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildMonthSelector(controller),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.transactions.isEmpty) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              if (controller.transactions.isEmpty) {
                return AppEmptyView(
                  message: 'No transactions this month',
                  subtitle: 'Start tracking your spending and income.',
                  icon: Icons.account_balance_wallet_outlined,
                  actionLabel: '+ Add Transaction',
                  onAction: () => CreateTransactionSheet.show(context),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  _buildTotalCard(context, controller),
                  const SizedBox(height: AppSpacing.lg),
                  _buildChart(context, controller),
                  const SizedBox(height: AppSpacing.lg),
                  _buildBudgetProgress(context, controller),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  ...controller.transactions.map((tx) => _buildTransactionTile(context, controller, tx)).toList(),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(FinanceController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: controller.previousMonth,
          ),
          Obx(() {
            final monthStr = DateFormat('MMMM yyyy').format(controller.currentMonth.value);
            return Text(
              monthStr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: controller.nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(BuildContext context, FinanceController controller) {
    final balance = controller.balance;
    final income = controller.totalIncome;
    final expense = controller.totalExpense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Text('Net Balance'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '\${balance >= 0 ? '+' : ''}\$${balance.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? Colors.green : Colors.red,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Income', style: TextStyle(color: Colors.grey)),
                    Text('\$${income.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Expense', style: TextStyle(color: Colors.grey)),
                    Text('\$${expense.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, FinanceController controller) {
    final expensesByCategory = controller.expensesByCategory;
    if (expensesByCategory.isEmpty) return const SizedBox.shrink();

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.brown,
    ];

    double total = controller.totalExpense;
    if (total == 0) return const SizedBox.shrink();

    int colorIndex = 0;
    List<Widget> segments = [];
    List<Widget> legend = [];

    expensesByCategory.forEach((category, amount) {
      if (amount > 0) {
        final color = colors[colorIndex % colors.length];
        final flex = (amount / total * 1000).toInt();
        
        segments.add(
          Expanded(
            flex: flex,
            child: Container(color: color),
          ),
        );
        
        legend.add(
          Padding(
            padding: const EdgeInsets.only(right: 12.0, bottom: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  '\${category.name.capitalizeFirst} (\${(amount / total * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
        
        colorIndex++;
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Expense Distribution', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 24,
                child: Row(children: segments),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(children: legend),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetProgress(BuildContext context, FinanceController controller) {
    final expensesByCategory = controller.expensesByCategory;
    if (expensesByCategory.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Budgets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ...controller.budgets.keys.map((cat) {
              if (cat == TransactionCategory.income) return const SizedBox.shrink();
              final spent = expensesByCategory[cat] ?? 0.0;
              final limit = controller.budgets[cat]!;
              final percent = (spent / limit).clamp(0.0, 1.0);
              
              Color progressColor = Theme.of(context).colorScheme.primary;
              if (percent >= 1.0) {
                progressColor = Colors.red;
              } else if (percent >= 0.8) {
                progressColor = Colors.orange;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat.name.capitalizeFirst!),
                        Text('\$${spent.toStringAsFixed(0)} / \$${limit.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent,
                      color: progressColor,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, FinanceController controller, FinanceTransaction tx) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: tx.isIncome ? Colors.green.withOpacity(0.2) : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _getIconForCategory(tx.category), 
          color: tx.isIncome ? Colors.green : Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(tx.title),
      subtitle: Row(
        children: [
          Text(DateFormat('MMM d, yyyy').format(tx.date)),
          if (tx.receiptUrl != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.receipt, size: 14, color: Colors.grey),
          ],
        ],
      ),
      trailing: Text(
        '${tx.isIncome ? "+" : "-"}\$${tx.amount.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: tx.isIncome ? Colors.green : Theme.of(context).colorScheme.error,
            ),
      ),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  controller.deleteTransaction(tx.id);
                  Navigator.pop(ctx);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForCategory(TransactionCategory cat) {
    switch (cat) {
      case TransactionCategory.income:
        return Icons.attach_money;
      case TransactionCategory.food:
        return Icons.restaurant;
      case TransactionCategory.transport:
        return Icons.directions_car;
      case TransactionCategory.utilities:
        return Icons.bolt;
      case TransactionCategory.entertainment:
        return Icons.movie;
      case TransactionCategory.shopping:
        return Icons.shopping_bag;
      case TransactionCategory.health:
        return Icons.medical_services;
      default:
        return Icons.receipt_long;
    }
  }
}
