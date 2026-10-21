import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/services/pulse/momentum_calculator.dart';
import '../../../domain/services/pulse/pattern_detector.dart';
import '../../controllers/pulse_controller.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_label.dart';
import '../../../core/services/demo_data_seeder.dart';

/// Momentum (four explainable dimensions) and Patterns (associations in the
/// user's own data, shown only with enough evidence).
class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final PulseController c = Get.find<PulseController>();

  @override
  void initState() {
    super.initState();
    DemoDataSeeder.checkStatus();
    c.loadInsights();
  }

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.responsiveGutter(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Obx(() {
              if (c.insightsLoading.value && c.insights.value == null) {
                return const AppLoadingView(message: 'Reading your entries');
              }
              if (c.insightsError.value != null && c.insights.value == null) {
                return AppErrorView(
                  message: c.insightsError.value!,
                  onRetry: c.loadInsights,
                );
              }
              final data = c.insights.value;
              if (data == null) {
                return RefreshIndicator(
                  onRefresh: c.loadInsights,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 48),
                    children: const [
                      EmptyState(
                        icon: Icons.show_chart,
                        message: 'Log a few moments and complete some tasks to see insights.',
                      ),
                      SizedBox(height: AppSpacing.xl),
                      _DemoDataInsightsCard(),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: c.loadInsights,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 48),
                  children: [
                    const SectionLabel(title: 'Momentum'),
                    for (final m in data.momentum.all) ...[
                      _MetricCard(metric: m),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    const SectionLabel(title: 'Patterns'),
                    if (data.patterns.isEmpty)
                      EmptyState(
                        icon: Icons.show_chart,
                        message: data.hasAnyData
                            ? 'No patterns yet. They appear once there are at '
                                  'least 8 days of entries that clearly differ.'
                            : 'Log a few moments and complete some tasks. '
                                  'Patterns appear after about two weeks.',
                      )
                    else
                      for (final p in data.patterns) ...[
                        _PatternTile(pattern: p),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    const SizedBox(height: AppSpacing.xl),
                    const _DemoDataInsightsCard(),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final MetricResult metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    final delta = metric.delta;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => _showWhy(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  metric.score?.toString() ?? '-',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metric.label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      metric.hasEnoughData
                          ? (delta == null || delta == 0
                                ? 'No change versus the previous period'
                                : '${delta > 0 ? '+' : ''}$delta versus the previous period')
                          : metric.missingReason ?? 'Not enough data yet',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.info_outline, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${metric.label}${metric.score == null ? '' : ': ${metric.score}'}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  metric.hasEnoughData
                      ? metric.explanation
                      : (metric.missingReason ?? 'Not enough data yet.'),
                  style: theme.textTheme.bodyMedium,
                ),
                if (metric.components.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Inputs', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  for (final comp in metric.components)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(comp.name)),
                          Text(
                            '${_fmt(comp.value)} ${comp.unit}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (metric.whyChanged.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('What changed', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  for (final line in metric.whyChanged)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(line),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({required this.pattern});

  final LifePattern pattern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pattern.statement, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(pattern.evidenceLine, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DemoDataInsightsCard extends StatefulWidget {
  const _DemoDataInsightsCard();

  @override
  State<_DemoDataInsightsCard> createState() => _DemoDataInsightsCardState();
}

class _DemoDataInsightsCardState extends State<_DemoDataInsightsCard> {
  bool _loading = false;
  StreamSubscription<bool>? _demoSub;

  @override
  void initState() {
    super.initState();
    _demoSub = DemoDataSeeder.isDemoMode.listen((_) {
      if (mounted) setState(() {});
    });
    DemoDataSeeder.checkStatus().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _demoSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);

    final isDemo = DemoDataSeeder.isDemoMode.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: isDemo
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDemo ? Icons.science_outlined : Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDemo ? 'Demo Mode Active' : 'Explore with Demo Data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isDemo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'TESTING MODE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isDemo
                ? 'Sample life events, tasks, habits, and finance transactions are currently loaded. Exit testing mode anytime to clear demo data and restore your normal user data.'
                : 'Populate sample life events, tasks, habits, and finance transactions to explore full momentum scores, patterns, and insights.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const ValueKey('demo_data_action_button'),
              onPressed: _loading
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      setState(() => _loading = true);

                      if (isDemo) {
                        final success = await DemoDataSeeder.clearDemoData();
                        if (!mounted) return;
                        setState(() => _loading = false);
                        messenger?.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Testing mode exited. Returned to normal user data.'
                                  : 'Failed to clear some demo data.',
                            ),
                          ),
                        );
                      } else {
                        final success = await DemoDataSeeder.seedAll();
                        if (!mounted) return;
                        setState(() => _loading = false);
                        messenger?.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Demo data loaded successfully across all modules!'
                                  : 'Failed to load some demo data.',
                            ),
                          ),
                        );
                      }
                    },
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isDemo ? Icons.restore : Icons.download,
                      size: 16,
                    ),
              label: Text(
                _loading
                    ? (isDemo ? 'Restoring data...' : 'Loading demo data...')
                    : (isDemo
                        ? 'Exit Testing Mode (Return to Normal Data)'
                        : 'Load Demo Data'),
              ),
              style: isDemo
                  ? OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.5),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}


