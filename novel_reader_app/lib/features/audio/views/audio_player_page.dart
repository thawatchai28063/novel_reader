import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../features/novels/views/novel_mode_page.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../controllers/audio_playback_controller.dart';
import '../controllers/audio_playback_scope.dart';
import '../widgets/audio_controls.dart';
import '../widgets/audio_hero.dart';
import '../widgets/audio_playlist_rail_button.dart';
import '../widgets/audio_clip_side_panel.dart';

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
