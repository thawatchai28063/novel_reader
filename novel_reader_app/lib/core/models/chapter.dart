import '../utils/json_readers.dart';

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
      id: readInt(map['id']),
      chapterNo: readInt(map['chapter_no']),
      title: '${map['title']}',
      content: '${map['content']}',
    );
  }
}
