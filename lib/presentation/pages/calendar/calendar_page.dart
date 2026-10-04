import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/repositories/calendar_repository_impl.dart';
import '../../../domain/repositories/calendar_repository.dart';
import '../../controllers/calendar_controller.dart';
import '../../../domain/usecases/calendar/get_agenda_for_range.dart';
import '../../widgets/calendar/calendar_day_cell.dart';
import '../../widgets/calendar/create_event_sheet.dart';
import '../../widgets/calendar/event_block.dart';
import '../../widgets/calendar/now_indicator.dart';
import '../../widgets/calendar/task_agenda_row.dart';
import '../../widgets/calendar/time_gutter.dart';
import '../../widgets/calendar/view_mode_switcher.dart';
import '../../widgets/notifications/notification_sheet.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayShortNames = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
];

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  CalendarController get controller {
    if (!Get.isRegistered<CalendarController>()) {
      if (!Get.isRegistered<CalendarRepository>()) {
        Get.lazyPut<CalendarRepository>(() => CalendarRepositoryImpl(), fenix: true);
      }
      return Get.put(CalendarController(), permanent: true);
    }
    return Get.find<CalendarController>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final surfaceColor = theme.colorScheme.surface;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: Obx(() {
          final focused = controller.focusedMonth.value;
          final monthStr = _monthNames[focused.month - 1];
          return Text(
            '$monthStr ${focused.year}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          );
        }),
        actions: [
          // "Today" button only appears when user is away from today
          Obx(() {
            if (controller.isTodaySelected) return const SizedBox.shrink();
            return TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                controller.jumpToToday();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            );
          }),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: 'Previous period',
            onPressed: () {
              HapticFeedback.lightImpact();
              controller.previousPeriod();
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: 'Next period',
            onPressed: () {
              HapticFeedback.lightImpact();
              controller.nextPeriod();
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.notifications_outlined, size: 20),
            tooltip: 'Notifications (Rubric D2)',
            onPressed: () => NotificationSheet.show(context),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Obx(() {
                    final sel = controller.selectedDate.value;
                    final dayStr = '${sel.day} ${_monthNames[sel.month - 1]}';
                    return Text(
                      dayStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Obx(
                  () => ViewModeSwitcher(
                    selectedMode: controller.viewMode.value,
                    onChanged: controller.changeViewMode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CreateEventSheet.show(
          context,
          initialDate: controller.selectedDate.value,
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        tooltip: 'Add event',
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.events.isEmpty) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        switch (controller.viewMode.value) {
          case CalendarViewMode.month:
            return _buildMonthView(context);
          case CalendarViewMode.week:
            return _buildWeekView(context);
          case CalendarViewMode.day:
            return _buildDayView(context);
        }
      }),
    );
  }

  // -------------------------------------------------------------
  // MONTH VIEW
  // -------------------------------------------------------------
  Widget _buildMonthView(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Column(
      children: [
        // Weekday header row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: Row(
            children: [
              for (final day in _weekdayShortNames)
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Month Grid
        Expanded(
          flex: 6,
          child: _buildMonthGrid(context),
        ),

        // Divider
        Divider(height: 1, thickness: 1, color: borderColor),

        // Agenda for Selected Day
        Expanded(
          flex: 4,
          child: _buildSelectedDayAgenda(context),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(BuildContext context) {
    final focused = controller.focusedMonth.value;
    final selected = controller.selectedDate.value;
    final now = DateTime.now();

    // First day of month
    final firstDayOfMonth = DateTime(focused.year, focused.month, 1);
    // Weekday: Monday is 1, Sunday is 7
    final firstWeekday = firstDayOfMonth.weekday; // 1 to 7

    // Start date to fill full grid (Monday before firstDay)
    final gridStartDate = firstDayOfMonth.subtract(Duration(days: firstWeekday - 1));

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.15,
          ),
          itemCount: 35, // 5 weeks standard
          itemBuilder: (context, index) {
            final cellDate = gridStartDate.add(Duration(days: index));
            final isCurrentMonth = cellDate.month == focused.month;
            final isToday = cellDate.year == now.year &&
                cellDate.month == now.month &&
                cellDate.day == now.day;
            final isSelected = cellDate.year == selected.year &&
                cellDate.month == selected.month &&
                cellDate.day == selected.day;

            final dayEvents = controller.eventsForDay(cellDate);

            return CalendarDayCell(
              date: cellDate,
              isCurrentMonth: isCurrentMonth,
              isToday: isToday,
              isSelected: isSelected,
              events: dayEvents,
              onTap: () => controller.selectDate(cellDate),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectedDayAgenda(BuildContext context) {
    final theme = Theme.of(context);
    final items = controller.agendaForSelectedDate;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 28,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing scheduled.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => CreateEventSheet.show(
                  context,
                  initialDate: controller.selectedDate.value,
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Event', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is AgendaEventItem) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: EventBlock(
              event: item.event,
              onTap: () => CreateEventSheet.show(
                context,
                eventToEdit: item.event,
              ),
            ),
          );
        } else if (item is AgendaTaskItem) {
          return TaskAgendaRow(
            task: item.task,
            onToggle: () => controller.toggleTask(item.task.id),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // -------------------------------------------------------------
  // DAY VIEW (Hourly Timeline with NowIndicator & Side-by-Side Packing)
  // -------------------------------------------------------------
  Widget _buildDayView(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final selectedDay = controller.selectedDate.value;
    final layoutItems = controller.overlapLayoutForDay(selectedDay);

    final allDayEvents = controller.eventsForDay(selectedDay).where((e) => e.isAllDay).toList();

    const double hourHeight = 60.0;
    const double totalTimelineHeight = hourHeight * 24;

    final isSelectedDayToday = selectedDay.year == DateTime.now().year &&
        selectedDay.month == DateTime.now().month &&
        selectedDay.day == DateTime.now().day;

    return Column(
      children: [
        // All-day strip pinned at top (if any exist)
        if (allDayEvents.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    'ALL-DAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      for (final ev in allDayEvents)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: EventBlock(
                            event: ev,
                            height: 28,
                            onTap: () => CreateEventSheet.show(context, eventToEdit: ev),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Scrollable 24-hour timeline
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: SizedBox(
              height: totalTimelineHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time gutter
                  const TimeGutter(hourHeight: hourHeight),

                  // Timeline grid & events
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final tappedHour = (details.localPosition.dy / hourHeight).floor().clamp(0, 23);
                        CreateEventSheet.show(
                          context,
                          initialDate: selectedDay,
                          initialStartTime: TimeOfDay(hour: tappedHour, minute: 0),
                        );
                      },
                      child: Stack(
                        children: [
                          // Hour grid lines
                          const Positioned.fill(
                            child: HourGridLines(hourHeight: hourHeight),
                          ),

                          // Positioned side-by-side event blocks
                          for (final item in layoutItems)
                            _buildPositionedBlock(
                              context: context,
                              item: item,
                              hourHeight: hourHeight,
                            ),

                          // Current-time line
                          if (isSelectedDayToday)
                            const NowIndicator(hourHeight: hourHeight),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionedBlock({
    required BuildContext context,
    required PositionedEventLayout item,
    required double hourHeight,
  }) {
    final top = (item.topMinutes / 60.0) * hourHeight;
    final height = (item.durationMinutes / 60.0) * hourHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final colWidth = totalWidth / item.totalColumns;
        final left = item.column * colWidth;

        return Positioned(
          top: top,
          left: left + 2,
          width: colWidth - 4,
          height: height.clamp(20.0, 1440.0),
          child: EventBlock(
            event: item.event,
            height: height,
            onTap: () => CreateEventSheet.show(
              context,
              eventToEdit: item.event,
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // WEEK VIEW (7 Columns with Sticky Day Header & Hourly Timeline)
  // -------------------------------------------------------------
  Widget _buildWeekView(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final selected = controller.selectedDate.value;
    final now = DateTime.now();

    // Start from Monday of the week
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    const double hourHeight = 52.0;

    return Column(
      children: [
        // Sticky 7-day Header
        Container(
          padding: const EdgeInsets.only(left: 48, right: 8, top: 8, bottom: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: Row(
            children: [
              for (final day in weekDays)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      controller.selectDate(day);
                    },
                    child: Column(
                      children: [
                        Text(
                          _weekdayShortNames[day.weekday - 1],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: day.year == now.year &&
                                  day.month == now.month &&
                                  day.day == now.day
                              ? BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                )
                              : (day.year == selected.year &&
                                      day.month == selected.month &&
                                      day.day == selected.day
                                  ? BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 1.5,
                                      ),
                                    )
                                  : null),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: day.year == now.year &&
                                      day.month == now.month &&
                                      day.day == now.day
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Scrollable Week Timeline
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              height: hourHeight * 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TimeGutter(hourHeight: hourHeight),
                  for (final day in weekDays)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: borderColor.withValues(alpha: 0.4), width: 0.5),
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: HourGridLines(hourHeight: hourHeight),
                            ),
                            for (final item in controller.overlapLayoutForDay(day))
                              _buildPositionedBlock(
                                context: context,
                                item: item,
                                hourHeight: hourHeight,
                              ),
                            if (day.year == now.year &&
                                day.month == now.month &&
                                day.day == now.day)
                              const NowIndicator(hourHeight: hourHeight),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
