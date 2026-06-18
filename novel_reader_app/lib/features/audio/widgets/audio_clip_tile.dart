import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../controllers/audio_playback_scope.dart';
import '../views/audio_player_page.dart';

class AudioClipTile extends StatelessWidget {
  const AudioClipTile({
    super.key,
    required this.novel,
    required this.clip,
    required this.clips,
  });

  final Novel novel;
  final AudioClipInfo clip;
  final List<AudioClipInfo> clips;

  @override
  Widget build(BuildContext context) {
    final controller = AudioPlaybackScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.isCurrentClip(novel, clip);
        final accent = selected ? Colors.orange : appSage(context);
        return AnimatedTapSurface(
          color: selected
              ? Colors.orange.withValues(alpha: 0.16)
              : appPaper(context),
          pressedColor: accent.withValues(alpha: 0.18),
          borderColor: selected
              ? Colors.orange
              : appInk(context).withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AudioPlayerPage(novel: novel, clip: clip, clips: clips),
              ),
            );
          },
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  selected ? Icons.graphic_eq : Icons.play_arrow,
                  color: accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clip.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? Colors.orange : appInk(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      selected
                          ? 'กำลังเล่นอยู่'
                          : '${clip.chapterCount} ตอนรวมกัน',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? Colors.orange
                            : appInk(context).withValues(alpha: 0.62),
                        fontWeight: selected ? FontWeight.w800 : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: accent,
              ),
            ],
          ),
        );
      },
    );
  }
}
