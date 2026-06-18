import 'package:flutter/material.dart';

import '../features/audio/controllers/audio_playback_controller.dart';
import '../features/audio/controllers/audio_playback_scope.dart';
import '../features/audio/views/audio_player_page.dart';
import '../features/audio/widgets/mini_audio_player.dart';
import '../features/novels/views/novel_list_page.dart';
import 'app_theme.dart';

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
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
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
}
