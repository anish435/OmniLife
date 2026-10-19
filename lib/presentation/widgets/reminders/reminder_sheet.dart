import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/reminder_text.dart';
import '../../../domain/entities/reminder.dart';
import '../../controllers/reminders_controller.dart';
import '../app_bottom_sheet_frame.dart';
import '../primary_button.dart';

/// Bottom sheet to add a reminder or edit an existing one.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({super.key, this.existing});

  final Reminder? existing;

  static Future<void> show(BuildContext context, {Reminder? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderSheet(existing: existing),
    );
  }

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  final RemindersController c = Get.find<RemindersController>();
  late final TextEditingController _title;
  late DateTime _at;
  late ReminderRepeat _repeat;
  String? _error;
  bool _saving = false;

  static const _repeatLabels = {
    ReminderRepeat.none: 'Once',
    ReminderRepeat.daily: 'Every day',
    ReminderRepeat.weekly: 'Every week',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _repeat = e?.repeat ?? ReminderRepeat.none;
    if (e != null) {
      _at = e.scheduledAt;
    } else {
      // Next whole hour, at least 30 minutes away.
      final t = c.now.add(const Duration(minutes: 30));
      _at = DateTime(
        t.year,
        t.month,
        t.day,
        t.hour,
      ).add(t.minute == 0 ? Duration.zero : const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = c.now;
    final first = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _at.isBefore(first) ? first : _at,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _at = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _at.hour,
        _at.minute,
      );
      _error = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (picked == null) return;
    setState(() {
      _at = DateTime(_at.year, _at.month, _at.day, picked.hour, picked.minute);
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final message = await c.save(
      existing: widget.existing,
      title: _title.text,
      at: _at,
      repeat: _repeat,
    );
    if (!mounted) return;
    if (message == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    final dayLabel = describeDay(_at, c.now);
    return AppBottomSheetFrame(
      title: editing ? 'Edit reminder' : 'New reminder',
      action: PrimaryButton(
        label: editing ? 'Save changes' : 'Save reminder',
        isFullWidth: true,
        isLoading: _saving,
        onPressed: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: !editing,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'What should we remind you about?',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(dayLabel, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(DateFormat('h:mm a').format(_at)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('How often?', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final entry in _repeatLabels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _repeat == entry.key,
                  onSelected: (_) => setState(() {
                    _repeat = entry.key;
                    _error = null;
                  }),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
