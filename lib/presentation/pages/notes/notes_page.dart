import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../controllers/notes_controller.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/app_error_view.dart';
import 'create_note_sheet.dart';
import 'note_card.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _searchController = TextEditingController();
  bool _searching = false;

  NotesController get controller => Get.find<NotesController>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchController.clear();
      controller.clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                key: const ValueKey('notes-search-field'),
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search title, tags, content',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: controller.setSearchInput,
              )
            : const Text('Notes'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search notes',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New note',
        onPressed: () => CreateNoteSheet.show(context),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final loading = controller.isLoading.value;
        final error = controller.errorMessage.value;
        final hasAny =
            controller.notes.isNotEmpty || controller.archivedNotes.isNotEmpty;

        if (loading && !hasAny) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (error != null && !hasAny) {
          return AppErrorView(message: error, onRetry: controller.loadNotes);
        }
        if (!hasAny && !controller.showArchived.value) {
          return AppEmptyView(
            message: 'No notes yet',
            subtitle: 'Capture your thoughts, ideas, and meeting notes.',
            icon: Icons.notes_outlined,
            actionLabel: 'New Note',
            onAction: () => CreateNoteSheet.show(context),
          );
        }

        final visible = controller.visibleNotes;
        final width = MediaQuery.sizeOf(context).width;

        return Column(
          children: [
            _FilterBar(controller: controller),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyResults(
                      controller: controller,
                      onClear: () {
                        controller.setCategory(null);
                        controller.setTag(null);
                        controller.clearSearch();
                        _searchController.clear();
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: controller.loadNotes,
                      child: MasonryGridView.count(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          AppSpacing.sm,
                          AppSpacing.screenPadding,
                          AppSpacing.section + 56,
                        ),
                        crossAxisCount: width > 600 ? 3 : 2,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final note = visible[index];
                          return NoteCard(
                            note: note,
                            onTap: () =>
                                CreateNoteSheet.show(context, noteToEdit: note),
                            onTogglePin: () async {
                              final ok = await controller.togglePin(note);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    !ok
                                        ? 'Could not update note'
                                        : (note.isPinned
                                              ? 'Note unpinned'
                                              : 'Note pinned'),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final NotesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = controller.categories;
      final tags = controller.allTags;
      final selectedCategory = controller.selectedCategory.value;
      final selectedTag = controller.selectedTag.value;
      final archived = controller.showArchived.value;

      return SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.xs,
          ),
          children: [
            AppChip(
              label: 'Archived',
              isSelected: archived,
              onSelected: (v) => controller.setShowArchived(v),
            ),
            for (final c in categories)
              AppChip(
                label: c,
                isSelected: selectedCategory == c,
                onSelected: (v) => controller.setCategory(v ? c : null),
              ),
            for (final t in tags)
              AppChip(
                label: '#$t',
                isSelected: selectedTag == t,
                onSelected: (v) => controller.setTag(v ? t : null),
              ),
          ],
        ),
      );
    });
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.controller, required this.onClear});

  final NotesController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final semantic = context.semanticColors;
      final query = controller.activeQuery.value;
      final archived = controller.showArchived.value;
      final filtered = controller.hasActiveFilters;

      final message = filtered
          ? (query.isNotEmpty
                ? 'No notes match "$query"'
                : 'No notes match these filters')
          : (archived ? 'No archived notes' : 'No notes yet');
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: semantic.mutedText),
            ),
          ),
          if (filtered)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ),
        ],
      );
    });
  }
}
