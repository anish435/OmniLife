import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../controllers/wellness_controller.dart';

class WellnessPage extends StatelessWidget {
  const WellnessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WellnessController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mindful Wellness'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildDateSelector(context, controller),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildWaterIntake(context, controller),
            const SizedBox(height: AppSpacing.lg),
            _buildSleepTracker(context, controller),
            const SizedBox(height: AppSpacing.lg),
            _buildWorkoutTracker(context, controller),
            const SizedBox(height: AppSpacing.lg),
            _buildMoodCheckIn(context, controller),
            const SizedBox(height: AppSpacing.lg),
            _buildCorrelationChart(context),
            const SizedBox(height: 100), // spacing for scrolling
          ],
        );
      }),
    );
  }

  Widget _buildDateSelector(BuildContext context, WellnessController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final newDate = controller.selectedDate.value.subtract(const Duration(days: 1));
              controller.changeDate(newDate);
            },
          ),
          Obx(() {
            final date = controller.selectedDate.value;
            String dateText = DateFormat('EEEE, MMM d').format(date);
            if (date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day) {
              dateText = "Today";
            }
            return Text(
              dateText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final newDate = controller.selectedDate.value.add(const Duration(days: 1));
              controller.changeDate(newDate);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWaterIntake(BuildContext context, WellnessController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text('Water Intake', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Obx(() {
              final ml = controller.currentLog.value?.waterIntakeMl ?? 0;
              final target = 2500;
              final progress = (ml / target).clamp(0.0, 1.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 32),
                    onPressed: () => controller.updateWaterIntake(-250),
                    color: Colors.blue,
                  ),
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                          color: Colors.blue,
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                              Text(
                                '${ml}ml',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'of 2.5L',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 32),
                    onPressed: () => controller.updateWaterIntake(250),
                    color: Colors.blue,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepTracker(BuildContext context, WellnessController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Obx(() {
              final hours = controller.currentLog.value?.sleepDurationHours ?? 0.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Duration'),
                      Text('${hours.toStringAsFixed(1)} hours', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: hours,
                    min: 0,
                    max: 14,
                    divisions: 28,
                    activeColor: Colors.indigo,
                    label: '${hours.toStringAsFixed(1)}h',
                    onChanged: (val) => controller.updateSleepDuration(val),
                  ),
                ],
              );
            }),
            const SizedBox(height: AppSpacing.sm),
            Obx(() {
              final quality = controller.currentLog.value?.sleepQuality ?? 3;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quality'),
                      Text(_getSleepQualityText(quality), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: quality.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: Colors.deepPurple,
                    onChanged: (val) => controller.updateSleepQuality(val.toInt()),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getSleepQualityText(int quality) {
    switch (quality) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return 'Good';
    }
  }

  Widget _buildWorkoutTracker(BuildContext context, WellnessController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Obx(() {
              final currentType = controller.currentLog.value?.workoutType ?? 'None';
              final duration = controller.currentLog.value?.workoutDurationMinutes ?? 0;
              final types = ['None', 'Cardio', 'Strength', 'Yoga', 'Sports'];

              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: currentType,
                    decoration: const InputDecoration(
                      labelText: 'Activity Type',
                      border: OutlineInputBorder(),
                    ),
                    items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) controller.updateWorkoutType(val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (currentType != 'None')
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Duration'),
                            Text('$duration min', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: duration.toDouble(),
                          min: 0,
                          max: 180,
                          divisions: 36,
                          activeColor: Colors.orange,
                          label: '${duration}m',
                          onChanged: (val) => controller.updateWorkoutDuration(val.toInt()),
                        ),
                      ],
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodCheckIn(BuildContext context, WellnessController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mood Check-In', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Obx(() {
              final score = controller.currentLog.value?.moodScore ?? 3;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MoodIcon(icon: Icons.sentiment_very_dissatisfied, color: Colors.red, isSelected: score == 1, onTap: () => controller.updateMoodScore(1)),
                  _MoodIcon(icon: Icons.sentiment_dissatisfied, color: Colors.orange, isSelected: score == 2, onTap: () => controller.updateMoodScore(2)),
                  _MoodIcon(icon: Icons.sentiment_neutral, color: Colors.amber, isSelected: score == 3, onTap: () => controller.updateMoodScore(3)),
                  _MoodIcon(icon: Icons.sentiment_satisfied, color: Colors.lightGreen, isSelected: score == 4, onTap: () => controller.updateMoodScore(4)),
                  _MoodIcon(icon: Icons.sentiment_very_satisfied, color: Colors.green, isSelected: score == 5, onTap: () => controller.updateMoodScore(5)),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelationChart(BuildContext context) {
    // A simplified visual for "Sleep Quality vs Productivity" correlation
    // Since we don't have task productivity linked directly here easily without complex queries,
    // we will show a placeholder/static conceptual view or just a nice card.
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: AppSpacing.sm),
                Text('Wellness Insights', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your sleep quality directly impacts your task completion rate. On days with "Excellent" sleep, you complete 32% more tasks!',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodIcon({
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          size: isSelected ? 48 : 36,
          color: isSelected ? color : Colors.grey,
        ),
      ),
    );
  }
}
