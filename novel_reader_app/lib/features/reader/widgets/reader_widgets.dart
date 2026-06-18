import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ChapterBookHeader extends StatelessWidget {
  const ChapterBookHeader({super.key, required this.novel});

  final Novel novel;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appGold(context).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          NovelCover(novel: novel, width: 76, height: 104),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  novel.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: appInk(context),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    InfoChip(
                      icon: Icons.format_list_numbered,
                      label: '${novel.chapterCount} ตอน',
                    ),
                    const InfoChip(
                      icon: Icons.headphones,
                      label: 'คลิปละ 10 ตอน',
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

class ChapterTile extends StatelessWidget {
  const ChapterTile({super.key, required this.chapter, required this.onTap});

  final ChapterSummary chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTapSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      color: appSurface(context),
      pressedColor: appSage(context).withValues(alpha: 0.12),
      borderColor: appInk(context).withValues(alpha: 0.06),
      elevation: 6,
      child: Row(
        children: [
          ChapterNumberBadge(number: chapter.chapterNo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: appInk(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${chapter.wordCount} คำ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: appInk(context).withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: appSage(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_right, color: appSage(context)),
          ),
        ],
      ),
    );
  }
}

class ChapterNumberBadge extends StatelessWidget {
  const ChapterNumberBadge({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: appSage(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$number',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: appSage(context),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class ReaderChapterNavigation extends StatelessWidget {
  const ReaderChapterNavigation({
    super.key,
    required this.currentIndex,
    required this.chapterCount,
    required this.previousChapter,
    required this.nextChapter,
    required this.onPrevious,
    required this.onContents,
    required this.onNext,
  });

  final int currentIndex;
  final int chapterCount;
  final ChapterSummary? previousChapter;
  final ChapterSummary? nextChapter;
  final VoidCallback? onPrevious;
  final VoidCallback onContents;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final positionText = currentIndex < 0
        ? 'สารบัญตอน'
        : 'ตอน ${currentIndex + 1} จาก $chapterCount';
    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: appSurface(context),
          border: Border(
            top: BorderSide(color: appGold(context).withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              positionText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: appInk(context).withValues(alpha: 0.64),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ReaderNavButton(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left),
                    label: 'ก่อนหน้า',
                    color: appSage(context),
                    tonal: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ReaderNavButton(
                    onPressed: onContents,
                    icon: const Icon(Icons.list_alt),
                    label: 'สารบัญ',
                    color: appGold(context),
                    tonal: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ReaderNavButton(
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right),
                    label: 'ถัดไป',
                    color: appSage(context),
                    tonal: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderNavButton extends StatelessWidget {
  const ReaderNavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.tonal,
    this.onPressed,
  });

  final Icon icon;
  final String label;
  final Color color;
  final bool tonal;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = tonal
        ? color.withValues(alpha: enabled ? 0.13 : 0.05)
        : color;
    final foreground = tonal ? color : Colors.white;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      opacity: enabled ? 1 : 0.45,
      child: AnimatedTapSurface(
        onTap: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        color: background,
        pressedColor: color.withValues(alpha: tonal ? 0.22 : 0.78),
        borderColor: color.withValues(alpha: tonal ? 0.18 : 0),
        elevation: enabled ? (tonal ? 4 : 10) : 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon.icon, size: 18, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderContentsSheet extends StatelessWidget {
  const ReaderContentsSheet({
    super.key,
    required this.chapters,
    required this.currentChapterId,
  });

  final List<ChapterSummary> chapters;
  final int currentChapterId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: appPaper(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: appInk(context).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: appGold(context).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.list_alt, color: appGold(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'สารบัญตอน',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: appInk(context),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          Text(
                            '${chapters.length} ตอน',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: appInk(
                                    context,
                                  ).withValues(alpha: 0.62),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิดสารบัญ',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: appInk(context).withValues(alpha: 0.08),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  itemCount: chapters.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    return ReaderContentsTile(
                      chapter: chapter,
                      selected: chapter.id == currentChapterId,
                      onTap: () => Navigator.of(context).pop(chapter),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ReaderContentsTile extends StatelessWidget {
  const ReaderContentsTile({
    super.key,
    required this.chapter,
    required this.selected,
    required this.onTap,
  });

  final ChapterSummary chapter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? appGold(context) : appSage(context);
    return AnimatedTapSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      color: selected
          ? appGold(context).withValues(alpha: 0.18)
          : appSurface(context),
      pressedColor: accent.withValues(alpha: 0.18),
      borderColor: selected
          ? appGold(context)
          : appInk(context).withValues(alpha: 0.08),
      elevation: selected ? 8 : 3,
      child: Row(
        children: [
          ChapterNumberBadge(number: chapter.chapterNo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chapter.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected ? appGold(context) : appInk(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (selected)
            Icon(Icons.check_circle, color: appGold(context))
          else
            Icon(Icons.chevron_right, color: appSage(context)),
        ],
      ),
    );
  }
}

class ReaderChapterHeader extends StatelessWidget {
  const ReaderChapterHeader({super.key, required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appSage(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: appGold(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_stories, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ตอนที่ ${chapter.chapterNo}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chapter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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
