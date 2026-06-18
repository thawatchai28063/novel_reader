import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../features/reader/widgets/reader_widgets.dart';
import '../widgets/audio_clips_panel.dart';

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
