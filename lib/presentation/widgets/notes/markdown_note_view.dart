import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/usecases/notes/checklist_parser.dart';

/// Renders note content as markdown. Task-list lines are drawn as our own
/// tappable rows (so a tap maps to an exact source line) and everything
/// between them is handed to the markdown renderer.
class MarkdownNoteView extends StatelessWidget {
  const MarkdownNoteView({
    super.key,
    required this.content,
    this.onToggleChecklist,
    this.emptyText = 'Nothing to preview yet.',
  });

  final String content;

  /// Called with the zero-based source line of the tapped checkbox.
  final ValueChanged<int>? onToggleChecklist;
  final String emptyText;

  static MarkdownStyleSheet styleSheetFor(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final base = MarkdownStyleSheet.fromTheme(theme);
    return base.copyWith(
      p: theme.textTheme.bodyMedium,
      h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      a: TextStyle(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      code: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: semantic.surfaceRaised,
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.smPlus),
      codeblockDecoration: BoxDecoration(
        color: semantic.surfaceRaised,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(color: semantic.hairline),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: semantic.hairline, width: 3)),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: semantic.hairline)),
      ),
    );
  }

  void _onTapLink(BuildContext context, String? href) {
    if (href == null || href.isEmpty) return;
    Clipboard.setData(ClipboardData(text: href));
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          emptyText,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.semanticColors.mutedText),
        ),
      );
    }

    final sheet = styleSheetFor(context);
    final children = <Widget>[];
    for (final seg in ChecklistParser.segments(content)) {
      final item = seg.item;
      if (item != null) {
        children.add(
          _ChecklistRow(
            item: item,
            styleSheet: sheet,
            onTap: onToggleChecklist == null
                ? null
                : () => onToggleChecklist!(item.lineIndex),
          ),
        );
      } else {
        children.add(
          MarkdownBody(
            data: seg.text!,
            styleSheet: sheet,
            onTapLink: (text, href, title) => _onTapLink(context, href),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.styleSheet,
    required this.onTap,
  });

  final ChecklistItem item;
  final MarkdownStyleSheet styleSheet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final checked = item.checked;
    final textStyle = (styleSheet.p ?? theme.textTheme.bodyMedium)?.copyWith(
      decoration: checked ? TextDecoration.lineThrough : null,
      color: checked ? semantic.mutedText : null,
    );

    return Semantics(
      container: true,
      checked: checked,
      label: item.text,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('checklist-line-${item.lineIndex}'),
          onTap: onTap,
          borderRadius: AppRadius.smallRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minRowHeight - 8,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: checked ? theme.colorScheme.primary : null,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: checked
                            ? theme.colorScheme.primary
                            : semantic.tertiaryText,
                        width: 1.5,
                      ),
                    ),
                    child: checked
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: theme.colorScheme.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.smPlus),
                  Expanded(child: Text(item.text, style: textStyle)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
