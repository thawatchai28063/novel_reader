import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const NovelReaderApp());
}

String get defaultApiBaseUrl {
  final configured = const String.fromEnvironment('API_BASE_URL').trim();
  if (configured.isNotEmpty) {
    return configured;
  }
  if (kIsWeb) {
    return 'http://localhost/novel_api/index.php';
  }
  return 'http://172.24.13.204/novel_api/index.php';
}

const _ink = Color(0xFF25221F);
const _paper = Color(0xFFF7F1E7);
const _surface = Color(0xFFFFFCF6);
const _sage = Color(0xFF355C4B);
const _teal = Color(0xFF1F6E73);
const _gold = Color(0xFFC8953E);
const _rose = Color(0xFF8E4352);
const _darkInk = Color(0xFFF0E6D8);
const _darkPaper = Color(0xFF101512);
const _darkSurface = Color(0xFF1B241F);
const _darkSage = Color(0xFF8DB99E);
const _darkGold = Color(0xFFD8AC5C);

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
  final AudioPlaybackController _audioController = AudioPlaybackController();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novel Reader',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 260),
      themeAnimationCurve: Curves.easeOut,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      builder: (context, child) {
        return AudioPlaybackScope(
          controller: _audioController,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            color: appPaper(context),
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                MiniAudioPlayer(
                  controller: _audioController,
                  onOpenPlayer: (novel, clip) {
                    _navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (_) => AudioPlayerPage(
                          novel: novel,
                          clip: clip,
                          clips: _audioController.queue,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sage,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class ApiClient {
  ApiClient(this.baseUrl);

  static const _requestTimeout = Duration(seconds: 10);
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

  Future<List<AudioClipInfo>> fetchAudioClips(int novelId) async {
    final data = await _get('audio_clips', {'novel_id': '$novelId'});
    return (data as List).map((item) => AudioClipInfo.fromJson(item)).toList();
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
      'เชื่อมต่อ API ไม่ได้ กรุณาตรวจว่า Apache/MySQL เปิดอยู่',
    );
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (response.statusCode >= 400) {
        throw ApiException('API error ${response.statusCode}');
      }
      throw const FormatException('Invalid API response');
    }
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

class AnimatedTapSurface extends StatefulWidget {
  const AnimatedTapSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.color,
    this.pressedColor,
    this.borderColor,
    this.borderRadius = 8,
    this.elevation = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? pressedColor;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;

  @override
  State<AnimatedTapSurface> createState() => _AnimatedTapSurfaceState();
}

class _AnimatedTapSurfaceState extends State<AnimatedTapSurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final color = widget.color ?? appSurface(context);
    final pressedColor =
        widget.pressedColor ?? appSage(context).withValues(alpha: 0.10);
    final shadowAlpha = Theme.of(context).brightness == Brightness.dark
        ? 0.32
        : 0.10;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
      decoration: BoxDecoration(
        color: _pressed ? pressedColor : color,
        borderRadius: radius,
        border: widget.borderColor == null
            ? null
            : Border.all(
                color: _pressed
                    ? appGold(context).withValues(alpha: 0.65)
                    : widget.borderColor!,
              ),
        boxShadow: [
          if (widget.elevation > 0)
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: _pressed ? widget.elevation * 0.55 : widget.elevation,
              offset: Offset(0, _pressed ? 4 : 8),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
          onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
          onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

int _readInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = '$value'.toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

String? _readOptionalString(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

class AudioPlaybackScope extends InheritedNotifier<AudioPlaybackController> {
  const AudioPlaybackScope({
    super.key,
    required AudioPlaybackController controller,
    required super.child,
  }) : super(notifier: controller);

  static AudioPlaybackController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AudioPlaybackScope>();
    assert(scope != null, 'AudioPlaybackScope is missing above this context');
    return scope!.notifier!;
  }
}

class AudioPlaybackController extends ChangeNotifier {
  AudioPlaybackController() {
    _playerSubscription = player.playerStateStream.listen(_handlePlayerState);
  }

  final AudioPlayer player = AudioPlayer();
  late final StreamSubscription<PlayerState> _playerSubscription;

  Novel? _novel;
  AudioClipInfo? _clip;
  double _speed = 1.0;
  bool _fullPlayerVisible = false;
  bool _loading = false;
  String? _error;
  List<AudioClipInfo> _queue = const [];
  bool _autoAdvancing = false;
  int _loadSerial = 0;

  Novel? get novel => _novel;
  AudioClipInfo? get clip => _clip;
  double get speed => _speed;
  bool get fullPlayerVisible => _fullPlayerVisible;
  bool get loading => _loading;
  String? get error => _error;
  List<AudioClipInfo> get queue => List.unmodifiable(_queue);
  bool get hasClip => _clip?.isPlayable ?? false;
  bool get shouldShowMiniPlayer =>
      hasClip && !_fullPlayerVisible && player.playing;
  int get currentIndex =>
      _clip == null ? -1 : _queue.indexWhere((item) => item.matches(_clip!));
  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex >= 0 && currentIndex < _queue.length - 1;

  bool isCurrentClip(Novel novel, AudioClipInfo clip) {
    final currentNovel = _novel;
    final currentClip = _clip;
    if (currentNovel == null || currentClip == null) return false;
    return currentNovel.id == novel.id && currentClip.matches(clip);
  }

  void _handlePlayerState(PlayerState state) {
    notifyListeners();
    if (state.processingState == ProcessingState.completed &&
        !_autoAdvancing &&
        hasNext) {
      _autoAdvancing = true;
      unawaited(playNext().whenComplete(() => _autoAdvancing = false));
    }
  }

  void _setQueue(List<AudioClipInfo>? clips, AudioClipInfo currentClip) {
    final playable = clips
        ?.where((clip) => clip.isPlayable)
        .toList(growable: false);
    if (playable != null && playable.isNotEmpty) {
      _queue = playable;
    }
    if (_queue.isEmpty || !_queue.any((clip) => clip.matches(currentClip))) {
      _queue = [currentClip];
    }
  }

  Future<void> playClip(
    Novel novel,
    AudioClipInfo clip, {
    List<AudioClipInfo>? queue,
  }) async {
    final loadSerial = ++_loadSerial;
    _setQueue(queue, clip);
    final audioUrl = clip.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      _novel = novel;
      _clip = clip;
      _error = 'ยังไม่มีไฟล์เสียงสำหรับคลิปนี้';
      _loading = false;
      notifyListeners();
      return;
    }

    final sameClip = _clip?.audioUrl == audioUrl;
    _novel = novel;
    _clip = clip;
    _error = null;
    _loading = true;
    notifyListeners();

    try {
      if (!sameClip) {
        await player.stop();
        await player.setUrl(audioUrl);
        await player.setSpeed(_speed);
        await player.play();
      } else if (!player.playing) {
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        await player.play();
      }
    } catch (error) {
      if (loadSerial == _loadSerial) {
        _error = '$error';
      }
    } finally {
      if (loadSerial == _loadSerial) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> playPrevious() async {
    final novel = _novel;
    final index = currentIndex;
    if (novel == null || index <= 0) return;
    await playClip(novel, _queue[index - 1], queue: _queue);
  }

  Future<void> playNext() async {
    final novel = _novel;
    final index = currentIndex;
    if (novel == null || index < 0 || index >= _queue.length - 1) return;
    await playClip(novel, _queue[index + 1], queue: _queue);
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else if (hasClip) {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  Future<void> seekBy(Duration offset) async {
    final duration = player.duration ?? Duration.zero;
    final next = player.position + offset;
    final clamped = next < Duration.zero
        ? Duration.zero
        : next > duration && duration > Duration.zero
        ? duration
        : next;
    await player.seek(clamped);
  }

  Future<void> setSpeed(double value) async {
    final next = value.clamp(0.5, 4.0).toDouble();
    _speed = next;
    notifyListeners();
    await player.setSpeed(next);
  }

  Future<void> stopAndClear() async {
    _loadSerial++;
    await player.stop();
    _novel = null;
    _clip = null;
    _queue = const [];
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void setFullPlayerVisible(bool visible) {
    if (_fullPlayerVisible == visible) return;
    _fullPlayerVisible = visible;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerSubscription.cancel();
    player.dispose();
    super.dispose();
  }
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
      id: _readInt(map['id']),
      title: '${map['title']}',
      chapterCount: _readInt(map['chapter_count']),
      author: _readOptionalString(map['author']),
      sourceName: _readOptionalString(map['source_name']),
      coverUrl: _readOptionalString(map['cover_url']),
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
      id: _readInt(map['id']),
      chapterNo: _readInt(map['chapter_no']),
      title: '${map['title']}',
      wordCount: _readInt(map['word_count']),
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
      id: _readInt(map['id']),
      chapterNo: _readInt(map['chapter_no']),
      title: '${map['title']}',
      content: '${map['content']}',
    );
  }
}

class AudioClipInfo {
  const AudioClipInfo({
    required this.index,
    required this.title,
    required this.firstChapter,
    required this.lastChapter,
    required this.chapterCount,
    required this.exists,
    this.audioUrl,
  });

  final int index;
  final String title;
  final int firstChapter;
  final int lastChapter;
  final int chapterCount;
  final bool exists;
  final String? audioUrl;

  bool get isPlayable => exists && (audioUrl?.isNotEmpty ?? false);

  bool matches(AudioClipInfo other) {
    final firstUrl = audioUrl;
    final secondUrl = other.audioUrl;
    if (firstUrl != null && secondUrl != null) {
      return firstUrl == secondUrl;
    }
    return firstChapter == other.firstChapter &&
        lastChapter == other.lastChapter;
  }

  factory AudioClipInfo.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return AudioClipInfo(
      index: _readInt(map['index']),
      title: '${map['title']}',
      firstChapter: _readInt(map['first_chapter']),
      lastChapter: _readInt(map['last_chapter']),
      chapterCount: _readInt(map['chapter_count']),
      exists: _readBool(map['exists']),
      audioUrl: _readOptionalString(map['audio_url']),
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
    setState(() => _future = _api.fetchNovels());
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
                          builder: (_) => NovelModePage(
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
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
                  '$novelCount เรื่อง • $chapterTotal ตอน • พร้อมโหมดฟัง',
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

class NovelModePage extends StatefulWidget {
  const NovelModePage({
    super.key,
    required this.api,
    required this.novel,
    this.themeMode = ThemeMode.system,
    this.onCycleThemeMode,
  });

  final ApiClient api;
  final Novel novel;
  final ThemeMode themeMode;
  final VoidCallback? onCycleThemeMode;

  @override
  State<NovelModePage> createState() => _NovelModePageState();
}

class _NovelModePageState extends State<NovelModePage> {
  late Future<List<AudioClipInfo>> _audioClipsFuture = widget.api
      .fetchAudioClips(widget.novel.id);

  @override
  void didUpdateWidget(covariant NovelModePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.novel.id != widget.novel.id) {
      _audioClipsFuture = widget.api.fetchAudioClips(widget.novel.id);
    }
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
          if (widget.onCycleThemeMode != null)
            ThemeModeButton(
              themeMode: widget.themeMode,
              onPressed: widget.onCycleThemeMode!,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ChapterBookHeader(novel: widget.novel),
          const SizedBox(height: 16),
          ModeActionTile(
            icon: Icons.menu_book,
            title: 'อ่านนิยาย',
            subtitle: '${widget.novel.chapterCount} ตอน',
            color: appSage(context),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChapterListPage(
                    api: widget.api,
                    novel: widget.novel,
                    themeMode: widget.themeMode,
                    onCycleThemeMode: widget.onCycleThemeMode ?? () {},
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<AudioClipInfo>>(
            future: _audioClipsFuture,
            builder: (context, snapshot) {
              final readyCount = (snapshot.data ?? const <AudioClipInfo>[])
                  .where((clip) => clip.isPlayable)
                  .length;
              final subtitle = snapshot.connectionState == ConnectionState.done
                  ? '$readyCount คลิปเสียง'
                  : 'กำลังนับคลิปเสียง';

              return ModeActionTile(
                icon: Icons.headphones,
                title: 'ฟังนิยายเสียง',
                subtitle: subtitle,
                color: _teal,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AudioClipListPage(
                        api: widget.api,
                        novel: widget.novel,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class ModeActionTile extends StatelessWidget {
  const ModeActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTapSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      color: appSurface(context),
      pressedColor: color.withValues(alpha: 0.13),
      borderColor: color.withValues(alpha: 0.16),
      elevation: 10,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: appInk(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appInk(context).withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_right, color: color),
          ),
        ],
      ),
    );
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

class AudioClipListPage extends StatefulWidget {
  const AudioClipListPage({super.key, required this.api, required this.novel});

  final ApiClient api;
  final Novel novel;

  @override
  State<AudioClipListPage> createState() => _AudioClipListPageState();
}

class _AudioClipListPageState extends State<AudioClipListPage> {
  late Future<List<AudioClipInfo>> _future = widget.api.fetchAudioClips(
    widget.novel.id,
  );

  void _reload() {
    setState(() {
      _future = widget.api.fetchAudioClips(widget.novel.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ฟังนิยายเสียง'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<AudioClipInfo>>(
        future: _future,
        builder: (context, snapshot) {
          final clips = snapshot.data ?? const <AudioClipInfo>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              ChapterBookHeader(novel: widget.novel),
              const SizedBox(height: 14),
              AudioClipsPanel(
                novel: widget.novel,
                clips: clips,
                loading: snapshot.connectionState != ConnectionState.done,
                error: snapshot.hasError ? '${snapshot.error}' : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

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
                  color: _teal.withValues(alpha: 0.16),
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

class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({
    super.key,
    required this.novel,
    required this.clip,
    this.clips = const [],
  });

  final Novel novel;
  final AudioClipInfo clip;
  final List<AudioClipInfo> clips;

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  final ApiClient _api = ApiClient(defaultApiBaseUrl);
  AudioPlaybackController? _controller;
  bool _started = false;
  bool _playlistOpen = false;
  int? _playlistNovelId;
  Future<List<AudioClipInfo>>? _playlistFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller = AudioPlaybackScope.of(context);
    _controller!.setFullPlayerVisible(true);
    if (_controller!.isCurrentClip(widget.novel, widget.clip)) {
      return;
    }
    unawaited(
      _controller!.playClip(widget.novel, widget.clip, queue: widget.clips),
    );
  }

  @override
  void dispose() {
    _controller?.setFullPlayerVisible(false);
    super.dispose();
  }

  Future<void> _retry() async {
    final controller = _controller ?? AudioPlaybackScope.of(context);
    await controller.playClip(
      controller.novel ?? widget.novel,
      controller.clip ?? widget.clip,
      queue: widget.clips.isNotEmpty ? widget.clips : controller.queue,
    );
  }

  Future<void> _goToNovel() async {
    if (!mounted) return;
    final controller = _controller ?? AudioPlaybackScope.of(context);
    final novel = controller.novel ?? widget.novel;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            NovelModePage(api: ApiClient(defaultApiBaseUrl), novel: novel),
      ),
    );
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _toggle() async {
    final controller = _controller ?? AudioPlaybackScope.of(context);
    await controller.toggle();
  }

  Future<void> _setSpeed(double value) async {
    final controller = _controller ?? AudioPlaybackScope.of(context);
    await controller.setSpeed(value);
  }

  Future<List<AudioClipInfo>> _playlistFutureFor(Novel novel) {
    if (_playlistNovelId != novel.id || _playlistFuture == null) {
      _playlistNovelId = novel.id;
      _playlistFuture = _api.fetchAudioClips(novel.id);
    }
    return _playlistFuture!;
  }

  List<AudioClipInfo> _playableClips(List<AudioClipInfo> clips) {
    return clips.where((clip) => clip.isPlayable).toList(growable: false);
  }

  List<AudioClipInfo> _fallbackClips(AudioPlaybackController controller) {
    final clips = widget.clips.isNotEmpty ? widget.clips : controller.queue;
    return _playableClips(clips);
  }

  Future<void> _selectClip(
    Novel novel,
    AudioClipInfo clip,
    List<AudioClipInfo> clips,
  ) async {
    setState(() => _playlistOpen = false);
    final controller = _controller ?? AudioPlaybackScope.of(context);
    await controller.playClip(novel, clip, queue: clips);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AudioPlaybackScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final error = controller.error;
        final currentNovel = controller.novel ?? widget.novel;
        final currentClip = controller.clip ?? widget.clip;
        final fallbackClips = _fallbackClips(controller);
        final playlistFuture = _playlistFutureFor(currentNovel);
        final width = MediaQuery.sizeOf(context).width;
        final panelWidth = width < 420 ? width * 0.82 : 340.0;
        return FutureBuilder<List<AudioClipInfo>>(
          future: playlistFuture,
          builder: (context, playlistSnapshot) {
            final fetchedClips = _playableClips(
              playlistSnapshot.data ?? const <AudioClipInfo>[],
            );
            final playlistClips = fetchedClips.isNotEmpty
                ? fetchedClips
                : fallbackClips;
            final playlistLoading =
                playlistSnapshot.connectionState != ConnectionState.done &&
                fetchedClips.isEmpty;
            final playlistError = playlistSnapshot.hasError
                ? '${playlistSnapshot.error}'
                : null;
            return Scaffold(
              appBar: AppBar(
                title: const Text('นิยายเสียง'),
                actions: [
                  IconButton(
                    tooltip: 'กลับหน้าหลัก',
                    onPressed: _goHome,
                    icon: const Icon(Icons.home_outlined),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      AudioHero(novel: currentNovel, clip: currentClip),
                      const SizedBox(height: 18),
                      if (error != null)
                        ErrorView(message: error, onRetry: _retry)
                      else
                        AudioControls(
                          controller: controller,
                          onSpeedChanged: _setSpeed,
                          onToggle: _toggle,
                          onGoToNovel: _goToNovel,
                          onGoHome: _goHome,
                        ),
                    ],
                  ),
                  if (_playlistOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _playlistOpen = false),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.42),
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: _playlistOpen ? 0 : -panelWidth,
                    top: 0,
                    bottom: 0,
                    width: panelWidth,
                    child: AudioClipSidePanel(
                      novel: currentNovel,
                      currentClip: currentClip,
                      clips: playlistClips,
                      loading: playlistLoading,
                      error: playlistError,
                      onClose: () => setState(() => _playlistOpen = false),
                      onSelect: (clip) =>
                          _selectClip(currentNovel, clip, playlistClips),
                    ),
                  ),
                  Positioned(
                    left: _playlistOpen ? panelWidth - 2 : 0,
                    top: 92,
                    child: SafeArea(
                      child: AudioPlaylistRailButton(
                        open: _playlistOpen,
                        clipCount: playlistClips.length,
                        onPressed: () =>
                            setState(() => _playlistOpen = !_playlistOpen),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AudioPlaylistRailButton extends StatelessWidget {
  const AudioPlaylistRailButton({
    super.key,
    required this.open,
    required this.clipCount,
    required this.onPressed,
  });

  final bool open;
  final int clipCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSage(context),
      elevation: 8,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      child: InkWell(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOut,
          width: 32,
          height: 112,
          decoration: BoxDecoration(
            color: open ? Colors.orange : appSage(context),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                open ? Icons.chevron_left : Icons.queue_music,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(height: 6),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  clipCount > 0 ? '$clipCount คลิป' : 'คลิป',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class AudioControls extends StatelessWidget {
  const AudioControls({
    super.key,
    required this.controller,
    required this.onSpeedChanged,
    required this.onToggle,
    required this.onGoToNovel,
    required this.onGoHome,
  });

  final AudioPlaybackController controller;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onToggle;
  final VoidCallback onGoToNovel;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final player = controller.player;
    final speed = controller.speed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appGold(context).withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final processing = state?.processingState;
              final loading =
                  processing == ProcessingState.loading ||
                  processing == ProcessingState.buffering;
              final playing = state?.playing ?? false;
              return SizedBox(
                height: 88,
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: PlayerControlButton(
                          tooltip: 'ตอนก่อนหน้า',
                          onPressed: loading || !controller.hasPrevious
                              ? null
                              : () => unawaited(controller.playPrevious()),
                          icon: const Icon(Icons.skip_previous),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: PlayerControlButton(
                          tooltip: 'ย้อนกลับ 10 วินาที',
                          onPressed: loading
                              ? null
                              : () => controller.seekBy(
                                  const Duration(seconds: -10),
                                ),
                          icon: const Icon(Icons.replay_10),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      child: Center(
                        child: PlayerPlayButton(
                          loading: loading,
                          playing: playing,
                          onPressed: loading ? null : onToggle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: PlayerControlButton(
                          tooltip: 'ข้ามไป 10 วินาที',
                          onPressed: loading
                              ? null
                              : () => controller.seekBy(
                                  const Duration(seconds: 10),
                                ),
                          icon: const Icon(Icons.forward_10),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: PlayerControlButton(
                          tooltip: 'ตอนถัดไป',
                          onPressed: loading || !controller.hasNext
                              ? null
                              : () => unawaited(controller.playNext()),
                          icon: const Icon(Icons.skip_next),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          AudioProgressBar(player: player),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGoHome,
                  icon: const Icon(Icons.home_outlined),
                  label: const FittedBox(child: Text('หน้าหลัก')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGoToNovel,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const FittedBox(child: Text('ไปที่นิยาย')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ความเร็ว',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}x',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Slider(
                  min: 0.5,
                  max: 4.0,
                  divisions: 14,
                  value: speed,
                  label: '${speed.toStringAsFixed(2)}x',
                  onChanged: onSpeedChanged,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final value in const [0.5, 1.0, 1.5, 2.0])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: value == 2.0 ? 0 : 8),
                          child: SpeedChoiceChip(
                            value: value,
                            selected: (speed - value).abs() < 0.01,
                            onSelected: () => onSpeedChanged(value),
                          ),
                        ),
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

class PlayerControlButton extends StatelessWidget {
  const PlayerControlButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Icon icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled
        ? appSage(context)
        : appInk(context).withValues(alpha: 0.28);
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        opacity: enabled ? 1 : 0.48,
        child: AnimatedTapSurface(
          onTap: onPressed,
          padding: EdgeInsets.zero,
          color: appPaper(context),
          pressedColor: appSage(context).withValues(alpha: 0.14),
          borderColor: appInk(context).withValues(alpha: 0.08),
          elevation: enabled ? 8 : 0,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon.icon, color: foreground, size: 26),
          ),
        ),
      ),
    );
  }
}

class PlayerPlayButton extends StatelessWidget {
  const PlayerPlayButton({
    super.key,
    required this.loading,
    required this.playing,
    required this.onPressed,
  });

  final bool loading;
  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing ? 'หยุดชั่วคราว' : 'เล่น',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB12E), Color(0xFFFF7A00)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: loading ? 0.18 : 0.42),
              blurRadius: loading ? 10 : 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Transform.translate(
                      offset: playing ? Offset.zero : const Offset(3, 0),
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AudioProgressBar extends StatelessWidget {
  const AudioProgressBar({super.key, required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: StreamBuilder<PlayerState>(
        stream: player.playerStateStream,
        builder: (context, playerSnapshot) {
          final processing = playerSnapshot.data?.processingState;
          final loading =
              processing == ProcessingState.loading ||
              processing == ProcessingState.buffering;
          return StreamBuilder<Duration?>(
            stream: player.durationStream,
            builder: (context, durationSnapshot) {
              final duration = durationSnapshot.data ?? player.duration;
              return StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  if (loading ||
                      duration == null ||
                      duration == Duration.zero) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const LinearProgressIndicator(minHeight: 4),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position)),
                            const Text('--:--'),
                          ],
                        ),
                      ],
                    );
                  }

                  final max = duration.inMilliseconds <= 0
                      ? 1.0
                      : duration.inMilliseconds.toDouble();
                  final value = position.inMilliseconds.toDouble().clamp(
                    0.0,
                    max,
                  );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Slider(
                        value: value,
                        max: max,
                        onChanged: (next) =>
                            player.seek(Duration(milliseconds: next.round())),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position)),
                          Text(_formatDuration(duration)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class SpeedChoiceChip extends StatelessWidget {
  const SpeedChoiceChip({
    super.key,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final double value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final label = '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}x';
    return AnimatedTapSurface(
      onTap: onSelected,
      padding: EdgeInsets.zero,
      color: selected ? Colors.orange : appPaper(context),
      pressedColor: Colors.orange.withValues(alpha: 0.22),
      borderColor: selected
          ? Colors.orange
          : appInk(context).withValues(alpha: 0.08),
      elevation: selected ? 8 : 2,
      child: SizedBox(
        height: 44,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? Colors.white : appInk(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({
    super.key,
    required this.controller,
    required this.onOpenPlayer,
  });

  final AudioPlaybackController controller;
  final void Function(Novel novel, AudioClipInfo clip) onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final novel = controller.novel;
        final clip = controller.clip;
        if (!controller.shouldShowMiniPlayer || novel == null || clip == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          right: 14,
          bottom: 18,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  StreamBuilder<Duration>(
                    stream: controller.player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = controller.player.duration;
                      final progress =
                          duration == null || duration == Duration.zero
                          ? null
                          : (position.inMilliseconds / duration.inMilliseconds)
                                .clamp(0.0, 1.0);
                      return InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onOpenPlayer(novel, clip),
                        child: Container(
                          width: 88,
                          height: 88,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: appSurface(context),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 78,
                                height: 78,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 5,
                                  backgroundColor: appInk(
                                    context,
                                  ).withValues(alpha: 0.12),
                                  color: Colors.orange,
                                ),
                              ),
                              StreamBuilder<PlayerState>(
                                stream: controller.player.playerStateStream,
                                builder: (context, snapshot) {
                                  final playing =
                                      snapshot.data?.playing ??
                                      controller.player.playing;
                                  return MiniCoverDisc(
                                    novel: novel,
                                    playing: playing,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MiniCoverDisc extends StatefulWidget {
  const MiniCoverDisc({super.key, required this.novel, required this.playing});

  final Novel novel;
  final bool playing;

  @override
  State<MiniCoverDisc> createState() => _MiniCoverDiscState();
}

class _MiniCoverDiscState extends State<MiniCoverDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    super.initState();
    _syncRotation();
  }

  @override
  void didUpdateWidget(covariant MiniCoverDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      _syncRotation();
    }
  }

  void _syncRotation() {
    if (widget.playing) {
      _rotation.repeat();
    } else {
      _rotation.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.novel.coverUrl?.trim();
    final coverAsset = widget.novel.coverAsset;
    return RotationTransition(
      turns: _rotation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: appInk(context).withValues(alpha: 0.16),
          border: Border.all(color: Colors.orange, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(
                alpha: widget.playing ? 0.38 : 0.2,
              ),
              blurRadius: widget.playing ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.music_note, color: Colors.orange),
                    )
                  : coverAsset != null
                  ? Image.asset(coverAsset, fit: BoxFit.cover)
                  : const Icon(Icons.music_note, color: Colors.orange),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.16),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                    stops: const [0.28, 0.52, 0.68, 1],
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.75,
              child: Container(
                width: 8,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.38),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appPaper(context),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.86),
                  width: 2.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class NovelCover extends StatelessWidget {
  const NovelCover({
    super.key,
    required this.novel,
    this.width = 64,
    this.height = 86,
  });

  final Novel novel;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final coverUrl = novel.coverUrl?.trim();
    final coverAsset = novel.coverAsset;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: width,
      height: height,
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
              errorBuilder: (context, error, stackTrace) =>
                  NovelCoverMark(title: novel.title),
            )
          : coverAsset != null
          ? Image.asset(coverAsset, fit: BoxFit.cover)
          : NovelCoverMark(title: novel.title),
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
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF6F343C)
          : _rose,
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
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: Tween<double>(begin: 0.08, end: 0).animate(animation),
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
          );
        },
        child: Icon(icon, key: ValueKey(themeMode)),
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
