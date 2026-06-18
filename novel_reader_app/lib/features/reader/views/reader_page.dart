import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../widgets/reader_widgets.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.api,
    required this.chapterId,
    required this.chapters,
    required this.themeMode,
    required this.onCycleThemeMode,
  });

  final ApiClient api;
  final int chapterId;
  final List<ChapterSummary> chapters;
  final ThemeMode themeMode;
  final VoidCallback onCycleThemeMode;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  double _fontSize = 19;
  late int _chapterId;
  late Future<Chapter> _future;

  @override
  void initState() {
    super.initState();
    _chapterId = widget.chapterId;
    _future = widget.api.fetchChapter(_chapterId);
  }

  int get _currentChapterIndex =>
      widget.chapters.indexWhere((chapter) => chapter.id == _chapterId);

  ChapterSummary? get _previousChapter {
    final index = _currentChapterIndex;
    if (index <= 0) return null;
    return widget.chapters[index - 1];
  }

  ChapterSummary? get _nextChapter {
    final index = _currentChapterIndex;
    if (index < 0 || index >= widget.chapters.length - 1) return null;
    return widget.chapters[index + 1];
  }

  void _openChapter(ChapterSummary chapter) {
    setState(() {
      _chapterId = chapter.id;
      _future = widget.api.fetchChapter(_chapterId);
    });
  }

  Future<void> _openContents() async {
    final selected = await showModalBottomSheet<ChapterSummary>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReaderContentsSheet(
        chapters: widget.chapters,
        currentChapterId: _chapterId,
      ),
    );
    if (selected != null) {
      _openChapter(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Chapter>(
      future: _future,
      builder: (context, snapshot) {
        final title = snapshot.data?.title ?? 'กำลังโหลด';
        final previousChapter = _previousChapter;
        final nextChapter = _nextChapter;
        return Scaffold(
          appBar: AppBar(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              ThemeModeButton(
                themeMode: widget.themeMode,
                onPressed: widget.onCycleThemeMode,
              ),
              IconButton(
                tooltip: 'ลดตัวอักษร',
                onPressed: () =>
                    setState(() => _fontSize = (_fontSize - 1).clamp(15, 28)),
                icon: const Icon(Icons.text_decrease),
              ),
              IconButton(
                tooltip: 'เพิ่มตัวอักษร',
                onPressed: () =>
                    setState(() => _fontSize = (_fontSize + 1).clamp(15, 28)),
                icon: const Icon(Icons.text_increase),
              ),
            ],
          ),
          bottomNavigationBar: ReaderChapterNavigation(
            currentIndex: _currentChapterIndex,
            chapterCount: widget.chapters.length,
            previousChapter: previousChapter,
            nextChapter: nextChapter,
            onPrevious: previousChapter == null
                ? null
                : () => _openChapter(previousChapter),
            onContents: _openContents,
            onNext: nextChapter == null
                ? null
                : () => _openChapter(nextChapter),
          ),
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorView(
                  message: '${snapshot.error}',
                  onRetry: () => setState(
                    () => _future = widget.api.fetchChapter(_chapterId),
                  ),
                );
              }
              final chapter = snapshot.data!;
              return SelectionArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                  children: [
                    ReaderChapterHeader(chapter: chapter),
                    const SizedBox(height: 18),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                      decoration: BoxDecoration(
                        color: appSurface(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: appGold(context).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        chapter.content,
                        style: TextStyle(
                          fontSize: _fontSize,
                          height: 1.78,
                          color: appInk(context),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
