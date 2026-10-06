import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/daily_steps.dart';

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Seven simple bars (no chart dependency). Today is drawn in the accent
/// colour, other days in a muted tone; an optional dashed-looking goal line
/// is drawn as a hairline. Each bar has a semantics label with its value.
class StepsBarChart extends StatelessWidget {
  const StepsBarChart({super.key, required this.days, this.goal});

  final List<DailySteps> days;
  final int? goal;

  static const double _plotHeight = 120;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.semanticColors.mutedText;
    final maxSteps = days.fold<int>(0, (m, d) => math.max(m, d.steps));
    final scaleMax = math.max(maxSteps, goal ?? 0).clamp(1, 1 << 30);
    final goalFraction = goal == null ? null : goal! / scaleMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _plotHeight,
          child: Stack(
            children: [
              if (goalFraction != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _plotHeight * goalFraction.clamp(0.0, 1.0),
                  child: Container(
                    key: const Key('steps_goal_line'),
                    height: 1,
                    color: theme.colorScheme.outline,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Semantics(
                          label:
                              '${_weekdayLetters[days[i].date.weekday - 1]}: '
                              '${days[i].steps} steps',
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              key: Key('steps_bar_$i'),
                              height: math.max(
                                2.0,
                                _plotHeight * days[i].steps / scaleMax,
                              ),
                              decoration: BoxDecoration(
                                color: i == days.length - 1
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: Text(
                  _weekdayLetters[d.date.weekday - 1],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
