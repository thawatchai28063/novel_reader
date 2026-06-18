import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';

class NovelTile extends StatelessWidget {
  const NovelTile({super.key, required this.novel, required this.onTap});

  final Novel novel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedTapSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: appSurface(context),
      pressedColor: appSage(context).withValues(alpha: 0.13),
      borderColor: appGold(context).withValues(alpha: 0.14),
      elevation: 12,
      child: Row(
        children: [
          NovelCover(novel: novel, width: 70, height: 96),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  novel.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: appInk(context),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    InfoChip(
                      icon: Icons.auto_stories,
                      label: '${novel.chapterCount} ตอน',
                    ),
                    const InfoChip(icon: Icons.graphic_eq, label: 'นิยายเสียง'),
                  ],
                ),
                if ((novel.sourceName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    novel.sourceName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: appInk(context).withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: appSage(context)),
        ],
      ),
    );
  }
}
