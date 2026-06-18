import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';

class AudioHero extends StatelessWidget {
  const AudioHero({super.key, required this.novel, required this.clip});

  final Novel novel;
  final AudioClipInfo clip;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appSage(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          NovelCover(novel: novel, width: 82, height: 112),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  novel.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  clip.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'รวม ${clip.chapterCount} ตอน',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
