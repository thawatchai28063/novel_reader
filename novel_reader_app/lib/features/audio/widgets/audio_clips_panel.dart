import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';
import 'audio_clip_tile.dart';

class AudioClipsPanel extends StatelessWidget {
  const AudioClipsPanel({
    super.key,
    required this.novel,
    required this.clips,
    required this.loading,
    this.error,
  });

  final Novel novel;
  final List<AudioClipInfo> clips;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final playable = clips
        .where((clip) => clip.isPlayable)
        .toList(growable: false);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appGold(context).withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: appTeal.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.headphones, color: appSage(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'นิยายเสียง',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: appInk(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loading
                          ? 'กำลังโหลดคลิปเสียง'
                          : '${playable.length} คลิปพร้อมฟัง • คลิปละ 10 ตอน',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: appInk(context).withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ] else if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ] else if (playable.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'ยังไม่มีไฟล์เสียงสำหรับเรื่องนี้',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: appInk(context).withValues(alpha: 0.66),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            for (final clip in playable) ...[
              AudioClipTile(novel: novel, clip: clip, clips: playable),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}
