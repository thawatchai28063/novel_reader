import '../utils/json_readers.dart';

class Novel {
  const Novel({
    required this.id,
    required this.title,
    required this.chapterCount,
    this.author,
    this.sourceName,
    this.coverUrl,
  });

  final int id;
  final String title;
  final int chapterCount;
  final String? author;
  final String? sourceName;
  final String? coverUrl;

  String? get coverAsset {
    if (title.contains('เน€เธเนเธฒเธเธญเธเธฃเนเธฒเธเธเธดเธจเธงเธ')) {
      return 'assets/covers/owner_store_mystery.jpg';
    }
    return null;
  }

  factory Novel.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return Novel(
      id: readInt(map['id']),
      title: '${map['title']}',
      chapterCount: readInt(map['chapter_count']),
      author: readOptionalString(map['author']),
      sourceName: readOptionalString(map['source_name']),
      coverUrl: readOptionalString(map['cover_url']),
    );
  }
}
