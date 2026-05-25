import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const NovelReaderApp());
}

String get defaultApiBaseUrl {
  if (kIsWeb) {
    return 'http://localhost/novel_api/index.php';
  }
  return 'http://172.24.13.204/novel_api/index.php';
}

const _ink = Color(0xFF2B2520);
const _paper = Color(0xFFFBF7EF);
const _surface = Color(0xFFFFFCF6);
const _sage = Color(0xFF496B5B);
const _gold = Color(0xFFC9963B);
const _wine = Color(0xFF8E3F46);
const _darkInk = Color(0xFFEDE4D6);
const _darkPaper = Color(0xFF151A17);
const _darkSurface = Color(0xFF202721);
const _darkSage = Color(0xFF8FB7A2);
const _darkGold = Color(0xFFD5AA58);

Color appInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _darkInk : _ink;
Color appPaper(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _darkPaper : _paper;
Color appSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _darkSurface : _surface;
Color appSage(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _darkSage : _sage;
Color appGold(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _darkGold : _gold;

class NovelReaderApp extends StatefulWidget {
  const NovelReaderApp({super.key});

  @override
  State<NovelReaderApp> createState() => _NovelReaderAppState();
}

class _NovelReaderAppState extends State<NovelReaderApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _cycleThemeMode() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novel Reader',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: NovelListPage(
        themeMode: _themeMode,
        onCycleThemeMode: _cycleThemeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final paper = isDark ? _darkPaper : _paper;
    final surface = isDark ? _darkSurface : _surface;
    final ink = isDark ? _darkInk : _ink;
    final sage = isDark ? _darkSage : _sage;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sage,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class ApiClient {
  ApiClient(this.baseUrl);

  static const _requestTimeout = Duration(seconds: 8);

  final String baseUrl;

  Uri _uri(String action, [Map<String, String>? params]) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(queryParameters: {'action': action, ...?params});
  }

  Future<List<Novel>> fetchNovels() async {
    final data = await _get('novels');
    return (data as List).map((item) => Novel.fromJson(item)).toList();
  }

  Future<List<ChapterSummary>> fetchChapters(int novelId) async {
    final data = await _get('chapters', {'novel_id': '$novelId'});
    return (data as List).map((item) => ChapterSummary.fromJson(item)).toList();
  }

  Future<Chapter> fetchChapter(int chapterId) async {
    final data = await _get('chapter', {'id': '$chapterId'});
    return Chapter.fromJson(data);
  }

  Future<Object?> _get(String action, [Map<String, String>? params]) async {
    final response = await http
        .get(_uri(action, params))
        .timeout(_requestTimeout, onTimeout: _timeout);
    final envelope = _decodeEnvelope(response);
    return envelope['data'];
  }

  Never _timeout() {
    throw TimeoutException(
      'เชื่อมต่อ API ไม่ได้ ตรวจว่า Apache/MySQL เปิดอยู่ และ API URL ถูกต้อง',
    );
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid API response');
    }
    if (response.statusCode >= 400 || decoded['ok'] != true) {
      throw ApiException('${decoded['error'] ?? 'API error'}');
    }
    return decoded;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Novel {
  const Novel({
    required this.id,
    required this.title,
    required this.chapterCount,
    this.author,
    this.sourceName,
    this.coverUrl,
  });

  final int id;
  final String title;
  final int chapterCount;
  final String? author;
  final String? sourceName;
  final String? coverUrl;

  String? get coverAsset {
    if (title.contains('เจ้าของร้านพิศวง')) {
      return 'assets/covers/owner_store_mystery.jpg';
    }
    return null;
  }

  factory Novel.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return Novel(
      id: int.parse('${map['id']}'),
      title: '${map['title']}',
      chapterCount: int.parse('${map['chapter_count'] ?? 0}'),
      author: map['author'] as String?,
      sourceName: map['source_name'] as String?,
      coverUrl: map['cover_url'] as String?,
    );
  }
}

class ChapterSummary {
  const ChapterSummary({
    required this.id,
    required this.chapterNo,
    required this.title,
    required this.wordCount,
  });

  final int id;
  final int chapterNo;
  final String title;
  final int wordCount;

  factory ChapterSummary.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return ChapterSummary(
      id: int.parse('${map['id']}'),
      chapterNo: int.parse('${map['chapter_no']}'),
      title: '${map['title']}',
      wordCount: int.parse('${map['word_count'] ?? 0}'),
    );
  }
}

class Chapter {
  const Chapter({
    required this.id,
    required this.chapterNo,
    required this.title,
    required this.content,
  });

  final int id;
  final int chapterNo;
  final String title;
  final String content;

  factory Chapter.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return Chapter(
      id: int.parse('${map['id']}'),
      chapterNo: int.parse('${map['chapter_no']}'),
      title: '${map['title']}',
      content: '${map['content']}',
    );
  }
}

class NovelListPage extends StatefulWidget {
  const NovelListPage({
    super.key,
    required this.themeMode,
    required this.onCycleThemeMode,
  });

  final ThemeMode themeMode;
  final VoidCallback onCycleThemeMode;

  @override
  State<NovelListPage> createState() => _NovelListPageState();
}

class _NovelListPageState extends State<NovelListPage> {
  final ApiClient _api = ApiClient(defaultApiBaseUrl);
  late Future<List<Novel>> _future = _api.fetchNovels();

  void _reload() {
    setState(() {
      _future = _api.fetchNovels();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คลังนิยาย'),
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
      body: FutureBuilder<List<Novel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}', onRetry: _reload);
          }
          final novels = snapshot.data ?? [];
          if (novels.isEmpty) {
            return const EmptyView();
          }
          final chapterTotal = novels.fold<int>(
            0,
            (total, novel) => total + novel.chapterCount,
          );
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                BookshelfHeader(
                  novelCount: novels.length,
                  chapterTotal: chapterTotal,
                ),
                const SizedBox(height: 16),
                for (final novel in novels) ...[
                  NovelTile(
                    novel: novel,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChapterListPage(
                            api: _api,
                            novel: novel,
                            themeMode: widget.themeMode,
                            onCycleThemeMode: widget.onCycleThemeMode,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class NovelTile extends StatelessWidget {
  const NovelTile({super.key, required this.novel, required this.onTap});

  final Novel novel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              NovelCover(novel: novel),
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
                        fontWeight: FontWeight.w800,
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
                        if ((novel.author ?? '').isNotEmpty)
                          InfoChip(icon: Icons.edit, label: novel.author!),
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
        ),
      ),
    );
  }
}

class BookshelfHeader extends StatelessWidget {
  const BookshelfHeader({
    super.key,
    required this.novelCount,
    required this.chapterTotal,
  });

  final int novelCount;
  final int chapterTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appSage(context),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: appSage(context).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: appGold(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_library,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ชั้นหนังสือของคุณ',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$novelCount เรื่อง • $chapterTotal ตอน',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
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

class NovelCoverMark extends StatelessWidget {
  const NovelCoverMark({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    final initial = trimmed.isEmpty
        ? 'น'
        : String.fromCharCode(trimmed.runes.first);
    return Container(
      width: 64,
      height: 86,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF6F343C)
            : _wine,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: appGold(context), width: 1.4),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: Colors.white24),
          ),
          Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: 7,
            bottom: 7,
            child: Icon(Icons.bookmark, color: appGold(context), size: 18),
          ),
        ],
      ),
    );
  }
}

class NovelCover extends StatelessWidget {
  const NovelCover({super.key, required this.novel});

  final Novel novel;

  @override
  Widget build(BuildContext context) {
    final coverUrl = novel.coverUrl?.trim();
    final coverAsset = novel.coverAsset;
    if ((coverUrl == null || coverUrl.isEmpty) && coverAsset == null) {
      return NovelCoverMark(title: novel.title);
    }

    return Container(
      width: 64,
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: appGold(context), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl != null && coverUrl.isNotEmpty
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                if (coverAsset != null) {
                  return Image.asset(coverAsset, fit: BoxFit.cover);
                }
                return NovelCoverMark(title: novel.title);
              },
            )
          : Image.asset(coverAsset!, fit: BoxFit.cover),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: appPaper(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: appSage(context)),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({
    super.key,
    required this.themeMode,
    required this.onPressed,
  });

  final ThemeMode themeMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (themeMode) {
      ThemeMode.system => (Icons.brightness_auto, 'ตามระบบ'),
      ThemeMode.light => (Icons.light_mode, 'โหมดสว่าง'),
      ThemeMode.dark => (Icons.dark_mode, 'โหมดมืด'),
    };
    return IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon));
  }
}

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
  late Future<List<ChapterSummary>> _future = widget.api.fetchChapters(
    widget.novel.id,
  );

  void _reload() {
    setState(() {
      _future = widget.api.fetchChapters(widget.novel.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
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
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}', onRetry: _reload);
          }
          final chapters = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              ChapterBookHeader(novel: widget.novel),
              const SizedBox(height: 14),
              for (final chapter in chapters) ...[
                ChapterTile(
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
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class ChapterBookHeader extends StatelessWidget {
  const ChapterBookHeader({super.key, required this.novel});

  final Novel novel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appGold(context).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          NovelCover(novel: novel),
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
                InfoChip(
                  icon: Icons.format_list_numbered,
                  label: '${novel.chapterCount} ตอน',
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
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: appSage(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${chapter.chapterNo}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: appSage(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: appInk(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.subject, size: 15, color: appGold(context)),
                        const SizedBox(width: 5),
                        Text(
                          '${chapter.wordCount} คำ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: appInk(context).withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: appSage(context)),
            ],
          ),
        ),
      ),
    );
  }
}

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
    if (index <= 0) {
      return null;
    }
    return widget.chapters[index - 1];
  }

  ChapterSummary? get _nextChapter {
    final index = _currentChapterIndex;
    if (index < 0 || index >= widget.chapters.length - 1) {
      return null;
    }
    return widget.chapters[index + 1];
  }

  void _openChapter(ChapterSummary chapter) {
    setState(() {
      _chapterId = chapter.id;
      _future = widget.api.fetchChapter(_chapterId);
    });
  }

  void _openContents() {
    Navigator.of(context).pop();
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
                  onRetry: () => setState(() {
                    _future = widget.api.fetchChapter(_chapterId);
                  }),
                );
              }
              final chapter = snapshot.data!;
              return SelectionArea(
                child: Container(
                  color: appPaper(context),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                    children: [
                      ReaderChapterHeader(chapter: chapter),
                      const SizedBox(height: 18),
                      Container(
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
                ),
              );
            },
          ),
        );
      },
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
      child: Container(
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
                  child: OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left),
                    label: const FittedBox(child: Text('ก่อนหน้า')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onContents,
                    icon: const Icon(Icons.list_alt),
                    label: const FittedBox(child: Text('สารบัญตอน')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right),
                    label: const FittedBox(child: Text('ถัดไป')),
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

class ReaderChapterHeader extends StatelessWidget {
  const ReaderChapterHeader({super.key, required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chapter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
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

class EmptyView extends StatelessWidget {
  const EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_library, size: 56),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีนิยาย',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}
