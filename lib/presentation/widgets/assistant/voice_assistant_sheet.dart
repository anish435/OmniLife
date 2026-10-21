import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/assistant/chat_message.dart';
import '../../controllers/assistant_controller.dart';
import 'assistant_action_card.dart';
import 'listening_dot.dart';

/// Modal bottom sheet popup for the Voice Assistant.
///
/// Automatically begins listening when opened, renders live audio transcription,
/// runs the Groq AI engine to execute tool actions (tasks, reminders, expenses, etc.),
/// displays result cards with Undo, and speaks the confirmation back.
class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key});

  /// Shows the voice assistant modal bottom sheet popup.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceAssistantSheet(),
    );
  }

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> {
  late final AssistantController _c = Get.find<AssistantController>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _c.ensureLoaded();
    // Start listening automatically on popup opening if configured
    if (_c.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _c.status.value == AssistantStatus.idle) {
          _c.startListening();
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    // Cancel listening and speech on dismiss
    if (_c.status.value == AssistantStatus.listening) {
      _c.cancelListening();
    }
    _c.voice.stopSpeaking();
    super.dispose();
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _c.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>();
    final muted = semantic?.mutedText ?? theme.colorScheme.onSurfaceVariant;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: AppRadius.smallRadius,
                ),
              ),
            ),

            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_none,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Voice Assistant',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Obx(
                    () => IconButton(
                      tooltip: _c.muted.value
                          ? 'Turn on spoken replies'
                          : 'Mute spoken replies',
                      onPressed: () => _c.setMuted(!_c.muted.value),
                      icon: Icon(
                        _c.muted.value
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Full screen chat',
                    onPressed: () {
                      Navigator.of(context).pop();
                      Get.toNamed(AppRoutes.assistant);
                    },
                    icon: const Icon(Icons.open_in_full, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Main Content
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: !_c.isConfigured
                    ? _buildNotConfigured(theme, muted)
                    : Obx(() {
                        final status = _c.status.value;
                        final partial = _c.partialTranscript.value;
                        final messages = _c.messages;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Active Listening Panel
                            if (status == AssistantStatus.listening)
                              _buildListeningCard(theme, partial),

                            // Thinking State
                            if (status == AssistantStatus.thinking)
                              _buildThinkingCard(theme),

                            // Recent Messages & Tool Results
                            if (messages.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _buildRecentActivity(theme, muted, messages),
                            ] else if (status == AssistantStatus.idle) ...[
                              _buildIdlePrompt(theme, muted),
                            ],
                          ],
                        );
                      }),
              ),
            ),

            // Bottom Actions & Text Composer
            _buildBottomControls(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConfigured(ThemeData theme, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Icon(Icons.key_off_outlined, size: 40, color: muted),
          const SizedBox(height: AppSpacing.sm),
          Text('Assistant not configured', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add GROQ_API_KEY to your .env file to enable the Voice Assistant.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListeningCard(ThemeData theme, String partial) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        borderRadius: AppRadius.largeRadius,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ListeningDot(size: 16),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Listening…',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            partial.isEmpty
                ? 'Speak now ("Add task", "I spent 150 on dinner", "Remind me tonight")'
                : '"$partial"',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: partial.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: partial.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smPlus,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Processing your request…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdlePrompt(ThemeData theme, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Text(
            'Tell me what you need.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap the microphone or type below. Shake phone twice anytime to summon me!',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(
    ThemeData theme,
    Color muted,
    List<ChatMessage> messages,
  ) {
    // Show only the last 3 messages to keep popup focused on the current action
    final recent = messages.length > 3
        ? messages.sublist(messages.length - 3)
        : messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final msg in recent) ...[
          if (msg.role == ChatRole.user)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: AppRadius.largeRadius,
                ),
                child: Text(
                  msg.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: AppRadius.largeRadius,
                ),
                child: Text(msg.text, style: theme.textTheme.bodyMedium),
              ),
            ),
            for (final card in msg.cards) ...[
              const SizedBox(height: AppSpacing.xs),
              AssistantActionCard(card: card, controller: _c),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.6),
        ),
      ),
      child: Row(
        children: [
          // Text Input Field
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Type a command…',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
              ),
              onSubmitted: (_) => _submitText(),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Send / Mic Button
          Obx(() {
            final isListening = _c.status.value == AssistantStatus.listening;
            return IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: isListening
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                foregroundColor: isListening
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onPrimary,
              ),
              tooltip: isListening ? 'Stop listening' : 'Speak',
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  _submitText();
                } else {
                  _c.toggleListening();
                }
              },
              icon: Icon(isListening ? Icons.stop : Icons.mic),
            );
          }),
        ],
      ),
    );
  }
}
