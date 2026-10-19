import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/assistant/chat_message.dart';
import '../../controllers/assistant_controller.dart';
import '../../widgets/assistant/listening_dot.dart';

/// A conversation with the assistant: you on the right, replies on the
/// left in plain text, and small cards for things it actually did.
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final AssistantController c = Get.find<AssistantController>();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Worker? _messagesWorker;

  @override
  void initState() {
    super.initState();
    c.ensureLoaded();
    _messagesWorker = ever(c.messages, (_) => _scrollToEnd());
    final args = Get.arguments;
    if (args is Map && args['listen'] == true && c.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.startListening();
      });
    }
  }

  @override
  void dispose() {
    _messagesWorker?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _submit() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    c.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final configured = c.isConfigured;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          if (configured) ...[
            Obx(
              () => IconButton(
                tooltip: c.muted.value
                    ? 'Turn on spoken replies'
                    : 'Mute spoken replies',
                onPressed: () => c.setMuted(!c.muted.value),
                icon: Icon(
                  c.muted.value
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  size: 22,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'clear') c.clearHistory();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear conversation'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: configured ? _thread(context) : const _NotConfigured(),
      ),
    );
  }

  Widget _thread(BuildContext context) {
    final gutter = AppSpacing.responsiveGutter(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                final msgs = c.messages;
                final thinking = c.status.value == AssistantStatus.thinking;
                if (msgs.isEmpty && !thinking) return const _EmptyThread();
                return ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    AppSpacing.md,
                    gutter,
                    AppSpacing.md,
                  ),
                  itemCount: msgs.length + (thinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == msgs.length) return const _Thinking();
                    return _MessageRow(message: msgs[i], controller: c);
                  },
                );
              }),
            ),
            _Listening(controller: c),
            _Composer(controller: c, input: _input, onSubmit: _submit),
          ],
        ),
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.extension<AppSemanticColors>()?.mutedText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The assistant isn\'t set up yet.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add GROQ_API_KEY to a .env file and run the app with '
              '--dart-define-from-file=.env (see docs/assistant.md).',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.extension<AppSemanticColors>()?.mutedText;
    final gutter = AppSpacing.responsiveGutter(context);
    const examples = [
      'Remind me to take tablets tonight',
      'I paid 200 to Alex today',
      'Add a task to call the bank tomorrow',
    ];
    return ListView(
      padding: EdgeInsets.all(gutter),
      children: [
        Text('Tell me what you need.', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'You can type, or tap the mic and speak. For example:',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.smPlus),
        for (final e in examples)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '“$e”',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        'Thinking…',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.extension<AppSemanticColors>()?.mutedText,
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.controller});

  final ChatMessage message;
  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == ChatRole.user;
    final width = MediaQuery.sizeOf(context).width;
    final maxBubble = (width * 0.82).clamp(0.0, 560.0);

    if (isUser) {
      final soft =
          theme.extension<AppSemanticColors>()?.accentSoft ??
          theme.colorScheme.primary.withValues(alpha: 0.14);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.smPlus),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubble),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.smPlus,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: AppRadius.mediumRadius,
              ),
              child: Text(message.text, style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (width * 0.92).clamp(0.0, 600.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.text, style: theme.textTheme.bodyMedium),
              for (final card in message.cards)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _ActionCardView(card: card, controller: controller),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCardView extends StatelessWidget {
  const _ActionCardView({required this.card, required this.controller});

  final ActionCard card;
  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>();
    final muted = semantic?.mutedText ?? theme.colorScheme.onSurfaceVariant;
    final struck =
        card.status == CardStatus.undone || card.status == CardStatus.cancelled;

    Widget? actions;
    switch (card.status) {
      case CardStatus.done:
        if (card.canUndo) {
          actions = TextButton(
            onPressed: () => controller.undo(card.id),
            child: const Text('Undo'),
          );
        }
      case CardStatus.awaitingConfirm:
        actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => controller.cancel(card.id),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => controller.confirm(card.id),
              child: const Text('Delete'),
            ),
          ],
        );
      case CardStatus.undone:
      case CardStatus.cancelled:
        break;
    }

    final status = switch (card.status) {
      CardStatus.undone => 'Undone',
      CardStatus.cancelled => 'Cancelled',
      _ => null,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.smPlus,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                status == null ? card.label : '${card.label} ($status)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: struck ? muted : null,
                  decoration: struck ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
          ?actions,
        ],
      ),
    );
  }
}

class _Listening extends StatelessWidget {
  const _Listening({required this.controller});

  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.status.value != AssistantStatus.listening) {
        return const SizedBox.shrink();
      }
      final theme = Theme.of(context);
      final text = controller.partialTranscript.value;
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.responsiveGutter(context),
        ),
        child: Row(
          children: [
            const ListeningDot(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text.isEmpty ? 'Listening…' : text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: text.isEmpty
                      ? theme.extension<AppSemanticColors>()?.mutedText
                      : null,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.input,
    required this.onSubmit,
  });

  final AssistantController controller;
  final TextEditingController input;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = AppSpacing.responsiveGutter(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: 'Type a message',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Obx(() {
            final listening =
                controller.status.value == AssistantStatus.listening;
            return IconButton(
              tooltip: listening ? 'Stop listening' : 'Speak',
              onPressed: controller.toggleListening,
              icon: Icon(
                listening ? Icons.mic : Icons.mic_none_outlined,
                color: listening ? theme.colorScheme.primary : null,
              ),
            );
          }),
          Obx(() {
            final busy = controller.status.value == AssistantStatus.thinking;
            return IconButton(
              tooltip: 'Send',
              onPressed: busy ? null : onSubmit,
              icon: const Icon(Icons.send_outlined),
            );
          }),
        ],
      ),
    );
  }
}
