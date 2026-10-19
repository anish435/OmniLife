import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/finance_transaction.dart';
import '../../../domain/services/finance_math.dart';

String _label(TransactionCategory c) =>
    c.name[0].toUpperCase() + c.name.substring(1);

String _money(double v) => '\$${v.toStringAsFixed(2)}';

Card _card(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.cardRadius,
      side: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        width: 1,
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child),
  );
}

Text _heading(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Text(
    text,
    style: theme.textTheme.labelSmall?.copyWith(
      letterSpacing: 0.8,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

/// Muted, distinct colours for chart slices. Drawn from the module palette
/// so charts match the rest of the app; flat fills, no gradients.
List<Color> sliceColors(BuildContext context) {
  final s = context.semanticColors;
  return [
    s.tasks,
    s.calendar,
    s.notes,
    s.habits,
    s.finance,
    s.wellness,
    s.warning,
    s.info,
  ];
}

/// Donut chart of this month's spending by category, with a plain legend.
class SpendingByCategoryCard extends StatelessWidget {
  const SpendingByCategoryCard({super.key, required this.slices});

  final List<CategorySpend> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = sliceColors(context);
    final total = slices.fold<double>(0, (a, s) => a + s.amount);

    final summary = slices
        .map(
          (s) =>
              '${_label(s.category)} ${_money(s.amount)}, '
              '${(s.share * 100).toStringAsFixed(0)} percent',
        )
        .join('; ');

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(context, 'WHERE THE MONEY WENT'),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: 'Spending by category: $summary',
            excludeSemantics: true,
            child: SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 54,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(enabled: false),
                      sections: [
                        for (var i = 0; i < slices.length; i++)
                          PieChartSectionData(
                            value: slices[i].amount,
                            color: colors[i % colors.length],
                            radius: 26,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Spent',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _money(total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < slices.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _label(slices[i].category),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${_money(slices[i].amount)}  '
                    '${(slices[i].share * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Income next to spending for each of the last few months.
class MonthlyTrendCard extends StatelessWidget {
  const MonthlyTrendCard({super.key, required this.months});

  final List<MonthlyTotals> months;

  @override
  Widget build(BuildContext context) {
    final hasData = months.any((m) => m.income > 0 || m.expense > 0);
    if (!hasData) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final incomeColor = context.semanticColors.success;
    final spentColor = AppColors.error;
    final peak = months.fold<double>(
      0,
      (a, m) => [a, m.income, m.expense].reduce((x, y) => x > y ? x : y),
    );

    final summary = months
        .map(
          (m) =>
              '${DateFormat('MMMM').format(m.month)}: '
              'income ${_money(m.income)}, spent ${_money(m.expense)}',
        )
        .join('; ');

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(context, 'INCOME AND SPENDING, MONTH BY MONTH'),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: 'Income and spending by month. $summary',
            excludeSemantics: true,
            child: SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: peak <= 0 ? 1 : peak * 1.15,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: peak <= 0 ? 1 : peak * 1.15 / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= months.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              DateFormat('MMM').format(months[i].month),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < months.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: months[i].income,
                            color: incomeColor,
                            width: 9,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: months[i].expense,
                            color: spentColor,
                            width: 9,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _swatch(incomeColor),
              const SizedBox(width: 6),
              Text('Income', style: theme.textTheme.bodySmall),
              const SizedBox(width: AppSpacing.md),
              _swatch(spentColor),
              const SizedBox(width: 6),
              Text('Spent', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _swatch(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// Each category's spending against its monthly limit, in plain words,
/// with a way to change the limits.
class BudgetsCard extends StatelessWidget {
  const BudgetsCard({super.key, required this.statuses, required this.onEdit});

  final List<BudgetStatus> statuses;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = statuses.where((s) => s.isOver).toList();

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _heading(context, 'BUDGETS')),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Change budgets'),
              ),
            ],
          ),
          if (over.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.smPlus),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: AppRadius.chipRadius,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      over.length == 1
                          ? 'You are over budget on '
                                '${_label(over.first.category).toLowerCase()} '
                                'this month.'
                          : 'You are over budget on ${over.length} things '
                                'this month.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final s in statuses) _row(context, s),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, BudgetStatus s) {
    final theme = Theme.of(context);
    Color color = theme.colorScheme.primary;
    if (s.level == BudgetLevel.over) {
      color = AppColors.error;
    } else if (s.level == BudgetLevel.nearLimit) {
      color = context.semanticColors.warning;
    }
    final messageStyle = theme.textTheme.bodySmall?.copyWith(
      color: s.isOver ? AppColors.error : theme.colorScheme.onSurfaceVariant,
      fontWeight: s.isOver ? FontWeight.w600 : FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.smPlus),
      child: Semantics(
        label:
            '${_label(s.category)}: spent ${_money(s.spent)}'
            '${s.hasBudget ? ' of ${_money(s.limit)}' : ''}. ${s.message}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _label(s.category),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  s.hasBudget
                      ? '${_money(s.spent)} of ${_money(s.limit)}'
                      : _money(s.spent),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (s.hasBudget) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: s.used.clamp(0.0, 1.0),
                  minHeight: 6,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(s.message, style: messageStyle),
          ],
        ),
      ),
    );
  }
}
