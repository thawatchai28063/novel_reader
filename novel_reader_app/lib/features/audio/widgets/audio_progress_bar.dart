import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioProgressBar extends StatelessWidget {
  const AudioProgressBar({super.key, required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: StreamBuilder<PlayerState>(
        stream: player.playerStateStream,
        builder: (context, playerSnapshot) {
          final processing = playerSnapshot.data?.processingState;
          final loading =
              processing == ProcessingState.loading ||
              processing == ProcessingState.buffering;
          return StreamBuilder<Duration?>(
            stream: player.durationStream,
            builder: (context, durationSnapshot) {
              final duration = durationSnapshot.data ?? player.duration;
              return StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  if (loading ||
                      duration == null ||
                      duration == Duration.zero) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const LinearProgressIndicator(minHeight: 4),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position)),
                            const Text('--:--'),
                          ],
                        ),
                      ],
                    );
                  }

                  final max = duration.inMilliseconds <= 0
                      ? 1.0
                      : duration.inMilliseconds.toDouble();
                  final value = position.inMilliseconds.toDouble().clamp(
                    0.0,
                    max,
                  );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Slider(
                        value: value,
                        max: max,
                        onChanged: (next) =>
                            player.seek(Duration(milliseconds: next.round())),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position)),
                          Text(_formatDuration(duration)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
