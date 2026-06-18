import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../widgets/reader_widgets.dart';
import 'reader_page.dart';

class ChapterListPage extends StatefulWidget {
  const ChapterListPage({
    super.key,
    required this.api,
    required this.novel,
    required this.themeMode,
    required this.onCycleThemeMode,
  });

  final ApiClient api;
  final Novel novel;
  final ThemeMode themeMode;
  final VoidCallback onCycleThemeMode;

  @override
  State<ChapterListPage> createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  late Future<List<ChapterSummary>> _chaptersFuture = widget.api.fetchChapters(
    widget.novel.id,
  );

  void _reload() {
    setState(() {
      _chaptersFuture = widget.api.fetchChapters(widget.novel.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.novel.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          ThemeModeButton(
            themeMode: widget.themeMode,
            onPressed: widget.onCycleThemeMode,
          ),
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ChapterSummary>>(
        future: _chaptersFuture,
        builder: (context, chapterSnapshot) {
          if (chapterSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (chapterSnapshot.hasError) {
            return ErrorView(
              message: '${chapterSnapshot.error}',
              onRetry: _reload,
            );
          }
          final chapters = chapterSnapshot.data ?? [];
          if (chapters.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ChapterBookHeader(novel: widget.novel),
                const SizedBox(height: 14),
                const EmptyView(),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: chapters.length + 3,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ChapterBookHeader(novel: widget.novel);
              }
              if (index == 1) {
                return const SizedBox(height: 14);
              }
              if (index == 2) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'สารบัญตอน',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: appInk(context),
                    ),
                  ),
                );
              }

              final chapter = chapters[index - 3];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChapterTile(
                  chapter: chapter,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReaderPage(
                          api: widget.api,
                          chapterId: chapter.id,
                          chapters: chapters,
                          themeMode: widget.themeMode,
                          onCycleThemeMode: widget.onCycleThemeMode,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
