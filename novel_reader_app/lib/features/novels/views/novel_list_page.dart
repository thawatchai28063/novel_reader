import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../widgets/bookshelf_header.dart';
import '../widgets/novel_tile.dart';
import 'novel_mode_page.dart';

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
