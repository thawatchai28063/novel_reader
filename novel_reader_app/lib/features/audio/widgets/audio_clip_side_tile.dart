import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';

class AudioClipSideTile extends StatelessWidget {
  const AudioClipSideTile({
    super.key,
    required this.clip,
    required this.selected,
    required this.onTap,
  });

  final AudioClipInfo clip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Colors.orange.withValues(alpha: 0.16);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedColor : appSurface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Colors.orange
                : appInk(context).withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.graphic_eq : Icons.play_circle_fill,
              color: selected ? Colors.orange : appSage(context),
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: appInk(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'รวม ${clip.chapterCount} ตอน',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: appInk(context).withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}
