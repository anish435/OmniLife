import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_spacing.dart';
import '../../controllers/habits_controller.dart';
import '../../widgets/app_empty_view.dart';
import 'create_habit_sheet.dart';
import 'habit_card.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HabitsController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits & Goals'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CreateHabitSheet.show(context),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.habits.isEmpty) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (controller.habits.isEmpty) {
          return AppEmptyView(
            message: 'No habits yet',
            subtitle: 'Start building momentum today.',
            icon: Icons.track_changes_outlined,
            actionLabel: 'New Habit',
            onAction: () => CreateHabitSheet.show(context),
          );
        }

        final habits = controller.habits;

        return RefreshIndicator(
          onRefresh: controller.loadHabits,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.section + 56,
            ),
            itemCount: habits.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final habit = habits[index];
              return HabitCard(habit: habit);
            },
          ),
        );
      }),
    );
  }
}
