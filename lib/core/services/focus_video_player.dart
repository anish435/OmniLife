import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Public sample video that is known to exist.
const String kSampleFocusVideoUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

enum FocusVideoStatus { idle, loading, ready, error }

@immutable
class FocusVideoState {
  const FocusVideoState({
    this.status = FocusVideoStatus.idle,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  final FocusVideoStatus status;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  FocusVideoState copyWith({
    FocusVideoStatus? status,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
  }) => FocusVideoState(
    status: status ?? this.status,
    isPlaying: isPlaying ?? this.isPlaying,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Looping ambient video behind the focus timer.
abstract class FocusVideoPlayer {
  ValueListenable<FocusVideoState> get state;

  /// Loads an http(s) URL. Failures end up in [state] as an error.
  Future<void> loadNetwork(String url);

  /// Loads a local file (mobile and desktop only).
  Future<void> loadFile(String path);

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);

  /// The video surface, or an empty box while nothing is loaded.
  Widget buildView();
  Future<void> dispose();
}

/// Whether [value] is an acceptable remote video address.
bool isValidVideoUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

class VideoPlayerFocusVideo implements FocusVideoPlayer {
  final _state = ValueNotifier(const FocusVideoState());
  VideoPlayerController? _controller;
  int _generation = 0;

  @override
  ValueListenable<FocusVideoState> get state => _state;

  @override
  Future<void> loadNetwork(String url) async {
    final trimmed = url.trim();
    if (!isValidVideoUrl(trimmed)) {
      _state.value = const FocusVideoState(
        status: FocusVideoStatus.error,
        errorMessage: 'Enter a valid http or https video address.',
      );
      return;
    }
    await _load(() => VideoPlayerController.networkUrl(Uri.parse(trimmed)));
  }

  @override
  Future<void> loadFile(String path) =>
      _load(() => VideoPlayerController.file(File(path)));

  Future<void> _load(VideoPlayerController Function() create) async {
    final generation = ++_generation;
    await _release();
    _state.value = const FocusVideoState(status: FocusVideoStatus.loading);
    VideoPlayerController? controller;
    try {
      controller = create();
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (generation != _generation) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      controller.addListener(_onTick);
      _controller = controller;
      _state.value = FocusVideoState(
        status: FocusVideoStatus.ready,
        duration: controller.value.duration,
      );
      await controller.play();
      _onTick();
    } catch (_) {
      try {
        await controller?.dispose();
      } catch (_) {}
      if (generation == _generation) {
        _state.value = const FocusVideoState(
          status: FocusVideoStatus.error,
          errorMessage:
              'This video could not be played. Check the address '
              'or your connection and try again.',
        );
      }
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      _state.value = const FocusVideoState(
        status: FocusVideoStatus.error,
        errorMessage: 'Playback failed. Try loading the video again.',
      );
      return;
    }
    _state.value = _state.value.copyWith(
      isPlaying: v.isPlaying,
      position: v.position,
      duration: v.duration,
    );
  }

  @override
  Future<void> play() async {
    try {
      await _controller?.play();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _controller?.pause();
    } catch (_) {}
  }

  @override
  Future<void> seekTo(Duration position) async {
    try {
      await _controller?.seekTo(position);
    } catch (_) {}
  }

  @override
  Widget buildView() {
    final c = _controller;
    if (c == null || _state.value.status != FocusVideoStatus.ready) {
      return const SizedBox.shrink();
    }
    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
      child: VideoPlayer(c),
    );
  }

  Future<void> _release() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.removeListener(_onTick);
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    _generation++;
    await _release();
    _state.dispose();
  }
}
