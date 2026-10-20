import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why voice input could not run (or stopped).
enum VoiceIssue { permissionDenied, unsupported, noSpeech, failed }

/// Plain-language explanation for the user.
String voiceIssueMessage(VoiceIssue issue) => switch (issue) {
  VoiceIssue.permissionDenied =>
    'I can\'t use the microphone. Allow microphone access in your browser or '
        'phone settings, or just type instead.',
  VoiceIssue.unsupported =>
    'Voice input isn\'t supported here. Chrome or Edge on the web and Android '
        'phones work, or you can type instead.',
  VoiceIssue.noSpeech => 'I didn\'t hear anything. Tap the mic and try again.',
  VoiceIssue.failed =>
    'Voice input stopped working. You can try again or type instead.',
};

/// Dictation and spoken replies behind one small seam, so the assistant
/// can be tested without a microphone.
abstract class VoiceService {
  /// Starts listening. Returns null when listening began, otherwise why not.
  /// [onPartial] gets the live transcript, [onFinal] the finished sentence,
  /// [onIssue] any later problem, and [onStopped] fires when listening ends.
  Future<VoiceIssue?> start({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(VoiceIssue issue) onIssue,
    void Function()? onStopped,
  });

  Future<void> stop();

  Future<void> speak(String text);

  Future<void> stopSpeaking();
}

/// [VoiceService] using speech_to_text (Chrome/Edge and Android) and
/// flutter_tts. Nothing initialises, and no permission is requested, until
/// the user first taps the mic.
class DeviceVoiceService implements VoiceService {
  DeviceVoiceService({SpeechToText? speech, FlutterTts? tts})
    : _speech = speech ?? SpeechToText(),
      _ttsOverride = tts;

  final SpeechToText _speech;
  final FlutterTts? _ttsOverride;
  FlutterTts? _tts;
  bool _ready = false;

  void Function(VoiceIssue)? _onIssue;
  void Function()? _onStopped;

  FlutterTts get _ttsEngine => _tts ??= (_ttsOverride ?? FlutterTts());

  Future<VoiceIssue?> _init() async {
    if (_ready) return null;
    try {
      final ok = await _speech.initialize(
        onError: _handleError,
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') _onStopped?.call();
        },
      );
      if (ok) {
        _ready = true;
        return null;
      }
      final permitted = await _speech.hasPermission;
      return permitted ? VoiceIssue.unsupported : VoiceIssue.permissionDenied;
    } catch (_) {
      return VoiceIssue.unsupported;
    }
  }

  void _handleError(SpeechRecognitionError e) {
    final msg = e.errorMsg;
    final issue = msg.contains('permission')
        ? VoiceIssue.permissionDenied
        : (msg == 'error_no_match' || msg == 'error_speech_timeout')
        ? VoiceIssue.noSpeech
        : msg.contains('not_supported') || msg.contains('language')
        ? VoiceIssue.unsupported
        : VoiceIssue.failed;
    _onIssue?.call(issue);
  }

  @override
  Future<VoiceIssue?> start({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(VoiceIssue issue) onIssue,
    void Function()? onStopped,
  }) async {
    _onIssue = onIssue;
    _onStopped = onStopped;
    final problem = await _init();
    if (problem != null) return problem;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) {
          if (r.finalResult) {
            onFinal(r.recognizedWords);
          } else {
            onPartial(r.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 6),
          listenFor: const Duration(seconds: 30),
        ),
      );
      return null;
    } catch (_) {
      return VoiceIssue.failed;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _ttsEngine.stop();
      await _ttsEngine.speak(text);
    } catch (_) {
      // Speech output is a nicety; the reply is already on screen.
    }
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

/// Used when the platform has no speech plugin at all.
class NoVoiceService implements VoiceService {
  const NoVoiceService();

  @override
  Future<VoiceIssue?> start({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(VoiceIssue issue) onIssue,
    void Function()? onStopped,
  }) async => VoiceIssue.unsupported;

  @override
  Future<void> stop() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stopSpeaking() async {}
}
