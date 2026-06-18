import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';
import '../controllers/audio_playback_controller.dart';
import 'mini_cover_disc.dart';

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({
    super.key,
    required this.controller,
    required this.onOpenPlayer,
  });

  final AudioPlaybackController controller;
  final void Function(Novel novel, AudioClipInfo clip) onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final novel = controller.novel;
        final clip = controller.clip;
        if (!controller.shouldShowMiniPlayer || novel == null || clip == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          right: 14,
          bottom: 18,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  StreamBuilder<Duration>(
                    stream: controller.player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = controller.player.duration;
                      final progress =
                          duration == null || duration == Duration.zero
                          ? null
                          : (position.inMilliseconds / duration.inMilliseconds)
                                .clamp(0.0, 1.0);
                      return InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onOpenPlayer(novel, clip),
                        child: Container(
                          width: 88,
                          height: 88,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: appSurface(context),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 78,
                                height: 78,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 5,
                                  backgroundColor: appInk(
                                    context,
                                  ).withValues(alpha: 0.12),
                                  color: Colors.orange,
                                ),
                              ),
                              StreamBuilder<PlayerState>(
                                stream: controller.player.playerStateStream,
                                builder: (context, snapshot) {
                                  final playing =
                                      snapshot.data?.playing ??
                                      controller.player.playing;
                                  return MiniCoverDisc(
                                    novel: novel,
                                    playing: playing,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
