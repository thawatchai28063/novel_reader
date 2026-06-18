import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/models/models.dart';

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
