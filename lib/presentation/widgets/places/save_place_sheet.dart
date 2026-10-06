import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/geo.dart';
import '../../../domain/entities/saved_location.dart';
import '../../controllers/places_controller.dart';
import '../app_bottom_sheet_frame.dart';

/// What the user chose in [SavePlaceSheet].
class SavePlaceResult {
  const SavePlaceResult({
    required this.name,
    required this.radiusMeters,
    this.linkedTaskId,
    this.linkedEventId,
    this.delete = false,
  });

  final String name;
  final double radiusMeters;
  final String? linkedTaskId;
  final String? linkedEventId;
  final bool delete;
}

/// Bottom sheet to name a place, pick its radius and optionally link a
/// task or calendar event. Used for both creating (tap / long-press on the
/// map) and editing ([existing] set, which also offers delete).
class SavePlaceSheet extends StatefulWidget {
  const SavePlaceSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.existing,
    this.linkOptions = const [],
  });

  final double latitude;
  final double longitude;
  final SavedLocation? existing;
  final List<LocationLinkOption> linkOptions;

  @override
  State<SavePlaceSheet> createState() => _SavePlaceSheetState();
}

class _SavePlaceSheetState extends State<SavePlaceSheet> {
  late final TextEditingController _name;
  late double _radius;
  String? _link; // 'task:<id>' | 'event:<id>'
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _radius = (e?.radiusMeters ?? SavedLocation.defaultRadiusMeters)
        .clamp(SavedLocation.minRadiusMeters, 2000)
        .toDouble();
    if (e?.linkedTaskId != null) {
      _link = 'task:${e!.linkedTaskId}';
    } else if (e?.linkedEventId != null) {
      _link = 'event:${e!.linkedEventId}';
    }
    // A stale link (task deleted) must not break the dropdown.
    if (_link != null && !_options().any((o) => o.value == _link)) {
      _link = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<String?>> _options() => [
    const DropdownMenuItem<String?>(value: null, child: Text('No link')),
    for (final o in widget.linkOptions)
      DropdownMenuItem<String?>(
        value: '${o.isTask ? 'task' : 'event'}:${o.id}',
        child: Text(
          '${o.isTask ? 'Task' : 'Event'}: ${o.label}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
  ];

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give this place a name');
      return;
    }
    String? task;
    String? event;
    if (_link != null) {
      final i = _link!.indexOf(':');
      final kind = _link!.substring(0, i);
      final id = _link!.substring(i + 1);
      if (kind == 'task') {
        task = id;
      } else {
        event = id;
      }
    }
    Navigator.of(context).pop(
      SavePlaceResult(
        name: name,
        radiusMeters: _radius,
        linkedTaskId: task,
        linkedEventId: event,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    return AppBottomSheetFrame(
      title: editing ? 'Edit place' : 'Save place',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.latitude.toStringAsFixed(5)}, '
              '${widget.longitude.toStringAsFixed(5)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('place_name_field'),
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Name', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Radius: ${formatDistance(_radius)}',
              style: theme.textTheme.labelLarge,
            ),
            Slider(
              key: const Key('place_radius_slider'),
              min: SavedLocation.minRadiusMeters,
              max: 2000,
              divisions: 99,
              value: _radius,
              label: formatDistance(_radius),
              onChanged: (v) => setState(() => _radius = v.roundToDouble()),
            ),
            DropdownButtonFormField<String?>(
              key: const Key('place_link_field'),
              isExpanded: true,
              initialValue: _link,
              decoration: const InputDecoration(labelText: 'Linked to'),
              items: _options(),
              onChanged: (v) => setState(() => _link = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (editing)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      SavePlaceResult(
                        name: widget.existing!.name,
                        radiusMeters: widget.existing!.radiusMeters,
                        delete: true,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('place_save_button'),
                  onPressed: _submit,
                  child: Text(editing ? 'Save changes' : 'Save place'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
