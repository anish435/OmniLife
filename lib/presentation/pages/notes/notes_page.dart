import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../app/theme/app_spacing.dart';
import '../../controllers/notes_controller.dart';
import '../../widgets/app_empty_view.dart';
import 'create_note_sheet.dart';
import 'note_card.dart';

class NotesPage extends GetView<NotesController> {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Search
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CreateNoteSheet.show(context),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.notes.isEmpty) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (controller.notes.isEmpty && controller.archivedNotes.isEmpty) {
          return AppEmptyView(
            message: 'No notes yet',
            subtitle: 'Capture your thoughts, ideas, and meeting notes.',
            icon: Icons.notes_outlined,
            actionLabel: 'New Note',
            onAction: () => CreateNoteSheet.show(context),
          );
        }

        final notes = controller.notes;

        return RefreshIndicator(
          onRefresh: controller.loadNotes,
          child: MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.section + 56,
            ),
            crossAxisCount: context.width > 600 ? 3 : 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return NoteCard(
                note: note,
                onTap: () => CreateNoteSheet.show(context, noteToEdit: note),
                onTogglePin: () => controller.togglePin(note),
              );
            },
          ),
        );
      }),
    );
  }
}
