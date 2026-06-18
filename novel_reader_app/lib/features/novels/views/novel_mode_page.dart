import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../features/audio/views/audio_clip_list_page.dart';
import '../../../features/reader/views/chapter_list_page.dart';
import '../../../features/reader/widgets/reader_widgets.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../widgets/mode_action_tile.dart';

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
                color: appTeal,
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
