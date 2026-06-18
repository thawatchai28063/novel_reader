import '../utils/json_readers.dart';

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
      id: readInt(map['id']),
      chapterNo: readInt(map['chapter_no']),
      title: '${map['title']}',
      wordCount: readInt(map['word_count']),
    );
  }
}
