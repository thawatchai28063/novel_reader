import 'package:flutter/widgets.dart';

import 'audio_playback_controller.dart';

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
