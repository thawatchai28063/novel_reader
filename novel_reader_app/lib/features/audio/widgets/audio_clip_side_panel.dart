import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';
import 'audio_clip_side_tile.dart';

class AudioClipSidePanel extends StatelessWidget {
  const AudioClipSidePanel({
    super.key,
    required this.novel,
    required this.currentClip,
    required this.clips,
    required this.loading,
    this.error,
    required this.onClose,
    required this.onSelect,
  });

  final Novel novel;
  final AudioClipInfo currentClip;
  final List<AudioClipInfo> clips;
  final bool loading;
  final String? error;
  final VoidCallback onClose;
  final ValueChanged<AudioClipInfo> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appPaper(context),
      elevation: 18,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: appSage(context).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.queue_music, color: appSage(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'เลือกคลิปเสียง',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: appInk(context),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loading
                              ? 'กำลังโหลดคลิปทั้งหมด'
                              : '${clips.length} คลิปพร้อมฟัง',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: appInk(context).withValues(alpha: 0.62),
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิดรายการคลิป',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                novel.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: appInk(context).withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: appInk(context).withValues(alpha: 0.08)),
            if (loading) const LinearProgressIndicator(minHeight: 3),
            if (error != null && clips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'โหลดรายการทั้งหมดไม่สำเร็จ กำลังใช้รายการล่าสุด',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: clips.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          loading
                              ? 'กำลังโหลดคลิปเสียงทั้งหมดของเรื่องนี้'
                              : error ?? 'ยังไม่มีคลิปเสียงในรายการนี้',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: error == null
                                    ? appInk(context).withValues(alpha: 0.62)
                                    : Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                      itemCount: clips.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final clip = clips[index];
                        return AudioClipSideTile(
                          clip: clip,
                          selected: clip.matches(currentClip),
                          onTap: () => onSelect(clip),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
