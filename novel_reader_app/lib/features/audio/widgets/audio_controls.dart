import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/app_theme.dart';
import '../controllers/audio_playback_controller.dart';
import 'audio_progress_bar.dart';
import 'player_control_button.dart';
import 'player_play_button.dart';
import 'speed_choice_chip.dart';

class AudioControls extends StatelessWidget {
  const AudioControls({
    super.key,
    required this.controller,
    required this.onSpeedChanged,
    required this.onToggle,
    required this.onGoToNovel,
    required this.onGoHome,
  });

  final AudioPlaybackController controller;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onToggle;
  final VoidCallback onGoToNovel;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final player = controller.player;
    final speed = controller.speed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appGold(context).withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final processing = state?.processingState;
              final loading =
                  processing == ProcessingState.loading ||
                  processing == ProcessingState.buffering;
              final playing = state?.playing ?? false;
              return SizedBox(
                height: 88,
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: PlayerControlButton(
                          tooltip: 'ตอนก่อนหน้า',
                          onPressed: loading || !controller.hasPrevious
                              ? null
                              : () => unawaited(controller.playPrevious()),
                          icon: const Icon(Icons.skip_previous),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: PlayerControlButton(
                          tooltip: 'ย้อนกลับ 10 วินาที',
                          onPressed: loading
                              ? null
                              : () => controller.seekBy(
                                  const Duration(seconds: -10),
                                ),
                          icon: const Icon(Icons.replay_10),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      child: Center(
                        child: PlayerPlayButton(
                          loading: loading,
                          playing: playing,
                          onPressed: loading ? null : onToggle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: PlayerControlButton(
                          tooltip: 'ข้ามไป 10 วินาที',
                          onPressed: loading
                              ? null
                              : () => controller.seekBy(
                                  const Duration(seconds: 10),
                                ),
                          icon: const Icon(Icons.forward_10),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: PlayerControlButton(
                          tooltip: 'ตอนถัดไป',
                          onPressed: loading || !controller.hasNext
                              ? null
                              : () => unawaited(controller.playNext()),
                          icon: const Icon(Icons.skip_next),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          AudioProgressBar(player: player),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGoHome,
                  icon: const Icon(Icons.home_outlined),
                  label: const FittedBox(child: Text('หน้าหลัก')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGoToNovel,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const FittedBox(child: Text('ไปที่นิยาย')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ความเร็ว',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}x',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Slider(
                  min: 0.5,
                  max: 4.0,
                  divisions: 14,
                  value: speed,
                  label: '${speed.toStringAsFixed(2)}x',
                  onChanged: onSpeedChanged,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final value in const [0.5, 1.0, 1.5, 2.0])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: value == 2.0 ? 0 : 8),
                          child: SpeedChoiceChip(
                            value: value,
                            selected: (speed - value).abs() < 0.01,
                            onSelected: () => onSpeedChanged(value),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
