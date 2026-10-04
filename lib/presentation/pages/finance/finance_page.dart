import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/finance_transaction.dart';
import '../../controllers/finance_controller.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/section_label.dart';
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
                  actionLabel: 'Add Transaction',
                  onAction: () => CreateTransactionSheet.show(context),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.screenPadding,
                  AppSpacing.screenPadding,
                  AppSpacing.section + 56,
                ),
                children: [
                  _buildTotalCard(context, controller),
                  const SizedBox(height: AppSpacing.lg),
                  _buildChart(context, controller),
                  const SizedBox(height: AppSpacing.lg),
                  _buildBudgetProgress(context, controller),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionLabel(title: 'RECENT TRANSACTIONS'),
                  const SizedBox(height: AppSpacing.sm),
                  ...controller.transactions.map((tx) => _buildTransactionTile(context, controller, tx)),
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
    final theme = Theme.of(context);
    final balance = controller.balance;
    final income = controller.totalIncome;
    final expense = controller.totalExpense;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              'NET BALANCE',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${balance < 0 ? "-" : ""}\$${balance.abs().toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: balance >= 0 ? context.semanticColors.success : AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'INCOME',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${income.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: context.semanticColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'EXPENSE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${expense.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
    final theme = Theme.of(context);
    final expensesByCategory = controller.expensesByCategory;
    if (expensesByCategory.isEmpty) return const SizedBox.shrink();

    final colors = [
      context.semanticColors.tasks,
      context.semanticColors.calendar,
      context.semanticColors.notes,
      context.semanticColors.habits,
      context.semanticColors.finance,
      context.semanticColors.wellness,
      context.semanticColors.warning,
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
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${category.name.capitalizeFirst} (${(amount / total * 100).toStringAsFixed(1)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        );
        
        colorIndex++;
      }
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'EXPENSE DISTRIBUTION',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.chipRadius,
              child: SizedBox(
                height: 20,
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
    final theme = Theme.of(context);
    final expensesByCategory = controller.expensesByCategory;
    if (expensesByCategory.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'BUDGETS',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...controller.budgets.keys.map((cat) {
              if (cat == TransactionCategory.income) return const SizedBox.shrink();
              final spent = expensesByCategory[cat] ?? 0.0;
              final limit = controller.budgets[cat]!;
              final percent = (spent / limit).clamp(0.0, 1.0);
              
              Color progressColor = theme.colorScheme.primary;
              if (percent >= 1.0) {
                progressColor = AppColors.error;
              } else if (percent >= 0.8) {
                progressColor = context.semanticColors.warning;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat.name.capitalizeFirst!,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '\$${spent.toStringAsFixed(0)} / \$${limit.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 6,
                        color: progressColor,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, FinanceController controller, FinanceTransaction tx) {
    final theme = Theme.of(context);
    final isIncome = tx.isIncome;
    final amountColor = isIncome ? context.semanticColors.success : theme.colorScheme.onSurface;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isIncome
            ? context.semanticColors.success.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          _getIconForCategory(tx.category), 
          size: 18,
          color: isIncome ? context.semanticColors.success : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        tx.title,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Text(
            DateFormat('MMM d, yyyy').format(tx.date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (tx.receiptUrl != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.receipt, size: 14, color: theme.colorScheme.onSurfaceVariant),
          ],
        ],
      ),
      trailing: Text(
        '${isIncome ? "+" : "-"}\$${tx.amount.toStringAsFixed(2)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: amountColor,
          fontFeatures: const [FontFeature.tabularFigures()],
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
