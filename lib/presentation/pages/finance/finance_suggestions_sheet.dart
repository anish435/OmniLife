import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/insights/finance_advice_service.dart';
import '../../../domain/insights/finance_suggestions.dart';
import '../../controllers/finance_controller.dart';

/// "Suggestions": plain tips from the real month. Rule-based tips show at
/// once and work with no network or key; when a written version is
/// available it replaces them (one request per open, cached).
class FinanceSuggestionsSheet extends StatefulWidget {
  const FinanceSuggestionsSheet({
    super.key,
    required this.controller,
    this.service,
    this.rules = const FinanceSuggestionRules(),
  });

  final FinanceController controller;

  /// Null means rule-based only.
  final FinanceAdviceService? service;
  final FinanceSuggestionRules rules;

  static Future<void> show(
    BuildContext context, {
    FinanceController? controller,
    FinanceAdviceService? service,
  }) {
    final c = controller ?? Get.find<FinanceController>();
    final svc =
        service ??
        (Get.isRegistered<FinanceAdviceService>()
            ? Get.find<FinanceAdviceService>()
            : null);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => FinanceSuggestionsSheet(controller: c, service: svc),
    );
  }

  @override
  State<FinanceSuggestionsSheet> createState() =>
      _FinanceSuggestionsSheetState();
}

class _FinanceSuggestionsSheetState extends State<FinanceSuggestionsSheet> {
  FinanceSuggestions? _shown;
  bool _writing = false;
  late final DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = widget.controller.currentMonth.value;
    unawaited(_load());
  }

  Future<void> _load() async {
    final c = widget.controller;
    final previous = await c.transactionsForMonth(
      DateTime(_month.year, _month.month - 1, 1),
    );
    final snapshot = FinanceSnapshot.fromTransactions(
      month: _month,
      current: List.of(c.transactions),
      previous: previous,
      budgets: Map.of(c.budgets),
    );
    if (!mounted) return;
    setState(() => _shown = widget.rules.build(snapshot));

    final service = widget.service;
    if (service == null || !service.canWrite || !snapshot.hasData) return;
    setState(() => _writing = true);
    final written = await service.write(snapshot);
    if (!mounted) return;
    setState(() {
      _writing = false;
      if (written != null) _shown = written;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _shown;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Text('Suggestions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            DateFormat('MMMM yyyy').format(_month),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (shown == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else ...[
            for (final section in shown.sections) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  section.title.toUpperCase(),
                  style: AppTypography.sectionLabel(
                    context.semanticColors.tertiaryText,
                  ),
                ),
              ),
              for (final b in section.bullets) _Bullet(text: b),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_writing)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Looking a little closer...',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.smPlus,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.smallRadius,
                border: Border.all(color: context.semanticColors.hairline),
              ),
              child: Text(
                FinanceSuggestions.disclaimer,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: AppSpacing.smPlus),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
