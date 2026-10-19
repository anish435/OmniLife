// Dependencies resolve lazily (Get.find) unless injected for tests, hence
// the private-named copies.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:get/get.dart';

import '../../data/assistant/chat_history_store.dart';
import '../../domain/assistant/ai_provider.dart';
import '../../domain/assistant/assistant_engine.dart';
import '../../domain/assistant/assistant_tool.dart';
import '../../domain/assistant/chat_message.dart';
import '../../domain/assistant/memory_store.dart';
import '../assistant/voice_service.dart';
import 'auth_controller.dart';

enum AssistantStatus { idle, listening, thinking }

/// State for the assistant thread: messages, the live voice transcript and
/// the result cards (with Undo / Confirm).
///
/// Typed commands are answered on screen only. Voice commands are spoken
/// back unless the user has muted replies.
class AssistantController extends GetxController {
  AssistantController({
    AssistantEngine? engine,
    VoiceService? voice,
    ChatHistoryStore? history,
    MemoryStore? memory,
    String? Function()? uidProvider,
    DateTime Function()? now,
    this.voiceStopGrace = const Duration(milliseconds: 350),
  }) : _engine = engine,
       _voice = voice,
       _history = history,
       _memory = memory,
       _uidProvider = uidProvider,
       _now = now ?? DateTime.now;

  AssistantEngine? _engine;
  VoiceService? _voice;
  ChatHistoryStore? _history;
  MemoryStore? _memory;
  final String? Function()? _uidProvider;
  final DateTime Function() _now;
  final Duration voiceStopGrace;

  AssistantEngine get engine => _engine ??= Get.find<AssistantEngine>();
  VoiceService get voice => _voice ??= Get.find<VoiceService>();
  ChatHistoryStore get historyStore =>
      _history ??= Get.find<ChatHistoryStore>();
  MemoryStore get memory => _memory ??= Get.isRegistered<MemoryStore>()
      ? Get.find<MemoryStore>()
      : const NoopMemoryStore();

  final messages = <ChatMessage>[].obs;
  final status = AssistantStatus.idle.obs;

  /// Live transcript while listening.
  final partialTranscript = ''.obs;

  /// Spoken replies off. Default on, but only voice commands are spoken.
  final muted = false.obs;

  bool get isConfigured => engine.isConfigured;

  final Map<String, ToolOutcome> _outcomes = {};
  final Set<String> _skipInHistory = {};
  bool _voiceHandled = false;
  bool _loadedOnce = false;
  Worker? _authWorker;
  var _seq = 0;

  String get _uid {
    final id = _uidProvider != null
        ? _uidProvider()
        : (Get.isRegistered<AuthController>()
              ? Get.find<AuthController>().currentUser.value?.uid
              : null);
    return (id == null || id.isEmpty) ? 'guest' : id;
  }

  @override
  void onInit() {
    super.onInit();
    if (_uidProvider == null && Get.isRegistered<AuthController>()) {
      _authWorker = ever(
        Get.find<AuthController>().currentUser,
        (_) => loadHistory(),
      );
    }
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    super.onClose();
  }

  /// Loads the saved thread for the current user (once per user change).
  Future<void> loadHistory() async {
    final saved = await historyStore.load(_uid);
    messages.assignAll(saved);
    _outcomes.clear();
    _loadedOnce = true;
  }

  Future<void> ensureLoaded() async {
    if (!_loadedOnce) await loadHistory();
  }

  String _id() => 'm${_now().microsecondsSinceEpoch}_${_seq++}';

  void _add(ChatRole role, String text, {List<ActionCard> cards = const []}) {
    messages.add(
      ChatMessage(
        id: _id(),
        role: role,
        text: text,
        createdAt: _now(),
        cards: cards,
      ),
    );
  }

  Future<void> _persist() => historyStore.save(_uid, messages.toList());

  // ----------------------------------------------------------- sending

  /// Handles one command. [viaVoice] decides whether the reply is spoken.
  Future<void> send(String text, {bool viaVoice = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || status.value == AssistantStatus.thinking) return;
    await ensureLoaded();

    final history = _historyForModel();
    _add(ChatRole.user, trimmed);
    status.value = AssistantStatus.thinking;
    await voice.stopSpeaking();

    AssistantTurn turn;
    try {
      final notes = await _recall();
      turn = await engine.handle(trimmed, history: history, memoryNotes: notes);
    } catch (_) {
      turn = const AssistantTurn(
        reply: 'Something went wrong on my side. Please try again.',
        failure: AiFailureKind.badResponse,
      );
    }

    final cards = <ActionCard>[];
    for (final o in turn.outcomes) {
      final card = _cardFor(o);
      if (card != null) cards.add(card);
    }
    _add(ChatRole.assistant, turn.reply, cards: cards);
    if (turn.failure != null) _skipInHistory.add(messages.last.id);
    status.value = AssistantStatus.idle;

    if (turn.failure == null && turn.outcomes.any((o) => o.isWrite)) {
      unawaited(
        memory.remember(
          _uid,
          MemoryEntry(
            text: '${_oneLine(trimmed)} -> ${_oneLine(turn.reply)}',
            at: _now(),
          ),
        ),
      );
    }
    await _persist();
    if (viaVoice && !muted.value) unawaited(voice.speak(turn.reply));
  }

  ActionCard? _cardFor(ToolOutcome o) {
    if (o.isWrite) {
      final card = ActionCard(
        id: _id(),
        label: o.label ?? o.spoken,
        status: CardStatus.done,
        canUndo: o.undo != null,
      );
      _outcomes[card.id] = o;
      return card;
    }
    if (o.status == ToolStatus.confirm) {
      final card = ActionCard(
        id: _id(),
        label: o.label ?? o.spoken,
        status: CardStatus.awaitingConfirm,
      );
      _outcomes[card.id] = o;
      return card;
    }
    return null;
  }

  List<AiMessage> _historyForModel() => [
    for (final m in messages)
      if (!_skipInHistory.contains(m.id) && m.text.trim().isNotEmpty)
        AiMessage(
          m.role == ChatRole.user ? AiRole.user : AiRole.assistant,
          m.text,
        ),
  ];

  Future<List<String>> _recall() async {
    try {
      final entries = await memory.recall(_uid);
      return [for (final e in entries) e.text];
    } catch (_) {
      return const [];
    }
  }

  String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // ------------------------------------------------------ cards: undo etc

  void _updateCard(String cardId, ActionCard Function(ActionCard) change) {
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final idx = m.cards.indexWhere((c) => c.id == cardId);
      if (idx == -1) continue;
      final cards = [...m.cards];
      cards[idx] = change(cards[idx]);
      messages[i] = m.copyWith(cards: cards);
      return;
    }
  }

  Future<void> undo(String cardId) async {
    final outcome = _outcomes[cardId];
    if (outcome?.undo == null) return;
    try {
      await outcome!.undo!();
      _updateCard(
        cardId,
        (c) => c.copyWith(status: CardStatus.undone, canUndo: false),
      );
    } catch (_) {
      _add(
        ChatRole.assistant,
        'I couldn\'t undo that. You can fix it from its own screen.',
      );
    }
    _outcomes.remove(cardId);
    await _persist();
  }

  Future<void> confirm(String cardId) async {
    final outcome = _outcomes[cardId];
    if (outcome?.onConfirm == null) return;
    _outcomes.remove(cardId);
    ToolOutcome result;
    try {
      result = await outcome!.onConfirm!();
    } catch (_) {
      result = ToolOutcome.failed('I couldn\'t do that. Please try again.');
    }
    if (result.isWrite) {
      _outcomes[cardId] = result;
      _updateCard(
        cardId,
        (c) => c.copyWith(
          label: result.label,
          status: CardStatus.done,
          canUndo: result.undo != null,
        ),
      );
    } else {
      _updateCard(cardId, (c) => c.copyWith(status: CardStatus.cancelled));
    }
    _add(ChatRole.assistant, AssistantEngine.composeReply([result]));
    await _persist();
  }

  Future<void> cancel(String cardId) async {
    _outcomes.remove(cardId);
    _updateCard(cardId, (c) => c.copyWith(status: CardStatus.cancelled));
    _add(ChatRole.assistant, 'Okay, I\'ve left it as it is.');
    await _persist();
  }

  Future<void> clearHistory() async {
    messages.clear();
    _outcomes.clear();
    _skipInHistory.clear();
    await historyStore.clear(_uid);
  }

  // ------------------------------------------------------------- voice

  void setMuted(bool value) {
    muted.value = value;
    if (value) unawaited(voice.stopSpeaking());
  }

  Future<void> toggleListening() => status.value == AssistantStatus.listening
      ? stopListening()
      : startListening();

  Future<void> startListening() async {
    if (status.value != AssistantStatus.idle) return;
    await ensureLoaded();
    await voice.stopSpeaking();
    partialTranscript.value = '';
    _voiceHandled = false;
    status.value = AssistantStatus.listening;
    final issue = await voice.start(
      onPartial: (t) => partialTranscript.value = t,
      onFinal: _onVoiceFinal,
      onIssue: _onVoiceIssue,
      onStopped: _onVoiceStopped,
    );
    if (issue != null) _voiceFailed(issue);
  }

  Future<void> stopListening() async {
    if (status.value != AssistantStatus.listening) return;
    await voice.stop();
    _onVoiceStopped();
  }

  void _onVoiceFinal(String text) {
    if (_voiceHandled) return;
    _voiceHandled = true;
    final spoken = text.trim().isEmpty ? partialTranscript.value : text;
    partialTranscript.value = '';
    status.value = AssistantStatus.idle;
    if (spoken.trim().isEmpty) {
      _voiceFailed(VoiceIssue.noSpeech);
      return;
    }
    unawaited(send(spoken, viaVoice: true));
  }

  void _onVoiceStopped() {
    // The final result can arrive just after the "stopped" status, so give
    // it a moment before deciding nothing was heard.
    Future<void>.delayed(voiceStopGrace, () {
      if (status.value != AssistantStatus.listening || _voiceHandled) return;
      _onVoiceFinal(partialTranscript.value);
    });
  }

  void _onVoiceIssue(VoiceIssue issue) {
    if (_voiceHandled) return;
    if (issue == VoiceIssue.noSpeech && partialTranscript.value.isNotEmpty) {
      _onVoiceFinal(partialTranscript.value);
      return;
    }
    _voiceHandled = true;
    _voiceFailed(issue);
  }

  void _voiceFailed(VoiceIssue issue) {
    partialTranscript.value = '';
    status.value = AssistantStatus.idle;
    _add(ChatRole.assistant, voiceIssueMessage(issue));
    _skipInHistory.add(messages.last.id);
  }
}
