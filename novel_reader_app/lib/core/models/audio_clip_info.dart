import '../utils/json_readers.dart';

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
      index: readInt(map['index']),
      title: '${map['title']}',
      firstChapter: readInt(map['first_chapter']),
      lastChapter: readInt(map['last_chapter']),
      chapterCount: readInt(map['chapter_count']),
      exists: readBool(map['exists']),
      audioUrl: readOptionalString(map['audio_url']),
    );
  }
}
