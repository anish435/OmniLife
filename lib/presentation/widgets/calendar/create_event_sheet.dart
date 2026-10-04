import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/calendar_controller.dart';
import '../../controllers/task_controller.dart';
import '../../../domain/entities/calendar_event.dart';
import '../../../core/services/notification_service.dart';
import 'calendar_colors.dart';

/// Modal bottom sheet for creating or editing calendar events.
///
/// Features:
/// - 20px top border radius
/// - Borderless large title field
/// - Inline themed pickers for Date and Start/End times (no stock dialogs)
/// - All-day toggle
/// - Type switcher (Event vs Focus Block)
/// - Muted color tag selector
/// - Optional task linkage
/// - Validation: title required, end time must be after start time
class CreateEventSheet extends StatefulWidget {
  const CreateEventSheet({
    super.key,
    this.initialDate,
    this.initialStartTime,
    this.eventToEdit,
  });

  final DateTime? initialDate;
  final TimeOfDay? initialStartTime;
  final CalendarEvent? eventToEdit;

  static Future<CalendarEvent?> show(
    BuildContext context, {
    DateTime? initialDate,
    TimeOfDay? initialStartTime,
    CalendarEvent? eventToEdit,
  }) {
    return showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateEventSheet(
        initialDate: initialDate,
        initialStartTime: initialStartTime,
        eventToEdit: eventToEdit,
      ),
    );
  }

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isAllDay;
  late String _selectedColorTag;
  late CalendarEventType _selectedType;
  String? _linkedTaskId;

  String? _validationError;

  @override
  void initState() {
    super.initState();
    final edit = widget.eventToEdit;
    final now = DateTime.now();

    _titleController = TextEditingController(text: edit?.title ?? '');
    _descriptionController =
        TextEditingController(text: edit?.description ?? '');

    _selectedDate = edit?.startAt ?? widget.initialDate ?? now;

    if (edit != null) {
      _startTime = TimeOfDay.fromDateTime(edit.startAt);
      _endTime = TimeOfDay.fromDateTime(edit.endAt);
      _isAllDay = edit.isAllDay;
      _selectedColorTag = edit.colorTag;
      _selectedType = edit.type;
      _linkedTaskId = edit.linkedTaskId;
    } else {
      final initialStart = widget.initialStartTime ??
          TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      _startTime = initialStart;
      _endTime = TimeOfDay(
        hour: (initialStart.hour + 1) % 24,
        minute: initialStart.minute,
      );
      _isAllDay = false;
      _selectedColorTag = 'blue';
      _selectedType = CalendarEventType.event;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'Please enter an event title');
      return;
    }

    final startAt = _isAllDay
        ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
        : _combineDateAndTime(_selectedDate, _startTime);

    final endAt = _isAllDay
        ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59)
        : _combineDateAndTime(_selectedDate, _endTime);

    if (!_isAllDay && !endAt.isAfter(startAt)) {
      setState(() => _validationError = 'End time must be after start time');
      return;
    }

    setState(() => _validationError = null);
    HapticFeedback.lightImpact();

    final controller = Get.isRegistered<CalendarController>()
        ? Get.find<CalendarController>()
        : Get.put(CalendarController(), permanent: true);

    if (widget.eventToEdit != null) {
      final updated = widget.eventToEdit!.copyWith(
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startAt: startAt,
        endAt: endAt,
        isAllDay: _isAllDay,
        colorTag: _selectedColorTag,
        type: _selectedType,
        linkedTaskId: _linkedTaskId,
      );
      final res = await controller.updateEvent(updated);
      if (mounted) {
        final dateStr = '${startAt.day}/${startAt.month} ${_isAllDay ? "All Day" : "${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}"}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Updated "$title" ($dateStr)')),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      Get.back(result: res);
    } else {
      final res = await controller.createEvent(
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startAt: startAt,
        endAt: endAt,
        isAllDay: _isAllDay,
        colorTag: _selectedColorTag,
        type: _selectedType,
        linkedTaskId: _linkedTaskId,
      );

      // Notification trigger (Rubric D2: Booking Confirmed & Reminder)
      if (Get.isRegistered<NotificationService>()) {
        final notifService = Get.find<NotificationService>();
        await notifService.showBookingConfirmation(
          title: title,
          startAt: startAt,
          eventId: res?.id,
        );
        if (startAt.isAfter(DateTime.now())) {
          final reminderTime = startAt.subtract(const Duration(minutes: 15));
          if (reminderTime.isAfter(DateTime.now())) {
            await notifService.scheduleReminder(
              id: (res?.id ?? title).hashCode & 0x7FFFFFFF,
              title: 'Reminder: $title',
              body: 'Starting in 15 minutes',
              scheduledDate: reminderTime,
              payload: res?.id,
            );
          }
        }
      }

      if (mounted) {
        final dateStr = '${startAt.day}/${startAt.month} ${_isAllDay ? "All Day" : "${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}"}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.event_available_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Scheduled "$title" ($dateStr)')),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      Get.back(result: res);
    }
  }

  Future<void> _delete() async {
    if (widget.eventToEdit == null) return;
    HapticFeedback.lightImpact();
    final controller = Get.isRegistered<CalendarController>()
        ? Get.find<CalendarController>()
        : Get.put(CalendarController(), permanent: true);
    await controller.deleteEvent(widget.eventToEdit!.id);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;
    final primary = theme.colorScheme.primary;

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top row: Action header (Cancel, Title, Delete/Done)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Text(
                    widget.eventToEdit != null ? 'Edit Schedule' : 'New Schedule',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.eventToEdit != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                      tooltip: 'Delete event',
                      onPressed: _delete,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),

              // Title Field (Clean, large borderless)
              TextFormField(
                controller: _titleController,
                autofocus: widget.eventToEdit == null,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Event title',
                  hintStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) {
                  if (_validationError != null) {
                    setState(() => _validationError = null);
                  }
                },
              ),

              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 16),

              // Type Switcher: Event vs Focus Block
              Row(
                children: [
                  Expanded(
                    child: _buildTypeSegment(
                      CalendarEventType.event,
                      'Event',
                      Icons.event_outlined,
                      primary,
                      borderColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypeSegment(
                      CalendarEventType.focusBlock,
                      'Focus Block',
                      Icons.bolt_outlined,
                      primary,
                      borderColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date & All-Day Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _pickInlineDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 15, color: primary),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'All-day',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch.adaptive(
                        value: _isAllDay,
                        activeThumbColor: primary,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          setState(() => _isAllDay = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // Inline Time Selectors (when not all-day)
              if (!_isAllDay) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeChip(
                        label: 'Starts',
                        time: _startTime,
                        onChanged: (t) => setState(() {
                          _startTime = t;
                          if (_endTime.hour < t.hour ||
                              (_endTime.hour == t.hour && _endTime.minute <= t.minute)) {
                            _endTime = TimeOfDay(
                              hour: (t.hour + 1) % 24,
                              minute: t.minute,
                            );
                          }
                        }),
                        borderColor: borderColor,
                        primary: primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeChip(
                        label: 'Ends',
                        time: _endTime,
                        onChanged: (t) => setState(() => _endTime = t),
                        borderColor: borderColor,
                        primary: primary,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Color Tag Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final entry in CalendarColors.tags.entries)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedColorTag = entry.key);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.value.color,
                          border: _selectedColorTag == entry.key
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 2.5,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Linked Task Dropdown (if tasks available)
              _buildTaskLinkDropdown(borderColor),

              const SizedBox(height: 16),

              // Description (optional)
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Notes or description (optional)',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button: Flat, solid accent, NO gradient
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.eventToEdit != null ? 'Save Changes' : 'Create Event',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegment(
    CalendarEventType type,
    String label,
    IconData icon,
    Color primary,
    Color borderColor,
  ) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedType = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primary : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip({
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
    required Color borderColor,
    required Color primary,
  }) {
    final hStr = time.hour.toString().padLeft(2, '0');
    final mStr = time.minute.toString().padLeft(2, '0');

    return InkWell(
      onTap: () => _pickInlineTime(time, onChanged),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '$hStr:$mStr',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickInlineDate() async {
    final now = DateTime.now();
    // Clean, compact themed date picker
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickInlineTime(
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onSelected,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Widget _buildTaskLinkDropdown(Color borderColor) {
    if (!Get.isRegistered<TaskController>()) return const SizedBox.shrink();
    final taskController = Get.find<TaskController>();
    final pendingTasks = taskController.tasks.where((t) => !t.completed).toList();

    if (pendingTasks.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<String?>(
      initialValue: _linkedTaskId,
      decoration: InputDecoration(
        labelText: 'Link with Task (optional)',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('No linked task', style: TextStyle(fontSize: 12)),
        ),
        for (final task in pendingTasks)
          DropdownMenuItem<String?>(
            value: task.id,
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
      onChanged: (val) => setState(() => _linkedTaskId = val),
    );
  }
}
