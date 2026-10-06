import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/ambient_audio_player.dart';
import '../../../core/services/focus_video_player.dart';
import '../../controllers/focus_controller.dart';
import '../../widgets/app_chip.dart';

BoxDecoration _panelDecoration(BuildContext context) {
  final semantic = context.semanticColors;
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: AppRadius.cardRadius,
    border: Border.all(color: semantic.hairline),
  );
}

/// Noise colour, play/pause and volume.
class AmbientSoundPanel extends StatelessWidget {
  const AmbientSoundPanel({super.key, required this.controller});

  final FocusController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.smPlus),
      decoration: _panelDecoration(context),
      child: ValueListenableBuilder<AmbientAudioState>(
        valueListenable: controller.audio.state,
        builder: (context, audio, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      runSpacing: 6,
                      children: [
                        for (final s in AmbientSound.values)
                          AppChip(
                            label: s.label,
                            isSelected: s == audio.sound,
                            onSelected: (_) => controller.selectSound(s),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: audio.isPlaying ? 'Pause sound' : 'Play sound',
                    onPressed: audio.sound == AmbientSound.off
                        ? null
                        : controller.toggleSound,
                    icon: Icon(
                      audio.isPlaying
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.volume_down_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Slider(
                      value: audio.volume,
                      onChanged: controller.setVolume,
                      semanticFormatterCallback: (v) =>
                          'Volume ${(v * 100).round()} percent',
                    ),
                  ),
                  Icon(
                    Icons.volume_up_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (audio.errorMessage != null)
                Text(
                  audio.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Video source input, looping preview, play/pause and seek.
class VideoPanel extends StatefulWidget {
  const VideoPanel({super.key, required this.controller});

  final FocusController controller;

  @override
  State<VideoPanel> createState() => _VideoPanelState();
}

class _VideoPanelState extends State<VideoPanel> {
  final _url = TextEditingController(text: kSampleFocusVideoUrl);

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smPlus),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            decoration: const InputDecoration(
              labelText: 'Video address',
              hintText: 'https://',
              isDense: true,
            ),
            onSubmitted: controller.loadVideoUrl,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                key: const Key('focus_video_load'),
                onPressed: () => controller.loadVideoUrl(_url.text),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Load video'),
              ),
              if (!kIsWeb)
                OutlinedButton.icon(
                  onPressed: controller.pickLocalVideo,
                  icon: const Icon(Icons.video_file_outlined, size: 18),
                  label: const Text('Choose from device'),
                ),
            ],
          ),
          ValueListenableBuilder<FocusVideoState>(
            valueListenable: controller.video.state,
            builder: (context, video, _) {
              switch (video.status) {
                case FocusVideoStatus.idle:
                  return const SizedBox.shrink();
                case FocusVideoStatus.loading:
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  );
                case FocusVideoStatus.error:
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.smPlus),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            video.errorMessage ??
                                'The video could not be played.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                case FocusVideoStatus.ready:
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.smPlus),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.smallRadius,
                          child: controller.video.buildView(),
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: video.isPlaying
                                  ? 'Pause video'
                                  : 'Play video',
                              onPressed: video.isPlaying
                                  ? controller.video.pause
                                  : controller.video.play,
                              icon: Icon(
                                video.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: video.duration.inMilliseconds == 0
                                    ? 0
                                    : video.position.inMilliseconds
                                          .clamp(
                                            0,
                                            video.duration.inMilliseconds,
                                          )
                                          .toDouble(),
                                max: video.duration.inMilliseconds == 0
                                    ? 1
                                    : video.duration.inMilliseconds.toDouble(),
                                onChanged: (v) => controller.video.seekTo(
                                  Duration(milliseconds: v.round()),
                                ),
                                semanticFormatterCallback: (_) =>
                                    'Video position',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}
