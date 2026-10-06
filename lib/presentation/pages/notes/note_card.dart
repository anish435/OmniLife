import 'package:flutter/material.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/note.dart';
import '../../../domain/usecases/notes/checklist_parser.dart';
import '../../widgets/calendar/calendar_colors.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onTogglePin,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  /// Plain-text preview of markdown: drops heading/list/emphasis markers.
  static String snippet(String content) {
    return content
        .split('\n')
        .map(
          (l) => l
              .replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')
              .replaceFirstMapped(
                RegExp(r'^\s*[-*+]\s+\[([ xX])\]\s+'),
                (m) => m.group(1) == ' ' ? '[ ] ' : '[x] ',
              )
              .replaceFirst(RegExp(r'^\s*[-*+]\s+'), '- ')
              .replaceAll(RegExp(r'[*_`]+'), ''),
        )
        .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('~~~'))
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final tag = CalendarColors.getTag(note.colorTag);
    final progress = ChecklistParser.progress(note.content);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: semantic.hairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note.colorTag != 'default')
              Container(height: 3, color: tag.color),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.smPlus),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      InkResponse(
                        onTap: onTogglePin,
                        radius: 18,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            note.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            semanticLabel: note.isPinned
                                ? 'Unpin note'
                                : 'Pin note',
                            size: 16,
                            color: note.isPinned
                                ? theme.colorScheme.primary
                                : semantic.tertiaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (note.content.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      snippet(note.content),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: semantic.mutedText,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${progress.done} of ${progress.total} done',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: semantic.tertiaryText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (note.category.isNotEmpty &&
                          note.category != 'General')
                        _Pill(label: note.category, filled: true),
                      for (final t in note.tags) _Pill(label: '#$t'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? semantic.accentSoft : null,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: semantic.hairline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: semantic.mutedText),
      ),
    );
  }
}
