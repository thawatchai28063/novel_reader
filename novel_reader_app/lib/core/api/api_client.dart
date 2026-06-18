import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

String get defaultApiBaseUrl {
  final configured = const String.fromEnvironment('API_BASE_URL').trim();
  if (configured.isNotEmpty) {
    return configured;
  }
  if (kIsWeb) {
    return 'http://localhost/novel_api/index.php';
  }
  return 'http://172.24.13.204/novel_api/index.php';
}

class ApiClient {
  ApiClient(this.baseUrl);

  static const _requestTimeout = Duration(seconds: 10);
  final String baseUrl;

  Uri _uri(String action, [Map<String, String>? params]) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(queryParameters: {'action': action, ...?params});
  }

  Future<List<Novel>> fetchNovels() async {
    final data = await _get('novels');
    return (data as List).map((item) => Novel.fromJson(item)).toList();
  }

  Future<List<ChapterSummary>> fetchChapters(int novelId) async {
    final data = await _get('chapters', {'novel_id': '$novelId'});
    return (data as List).map((item) => ChapterSummary.fromJson(item)).toList();
  }

  Future<Chapter> fetchChapter(int chapterId) async {
    final data = await _get('chapter', {'id': '$chapterId'});
    return Chapter.fromJson(data);
  }

  Future<List<AudioClipInfo>> fetchAudioClips(int novelId) async {
    final data = await _get('audio_clips', {'novel_id': '$novelId'});
    return (data as List).map((item) => AudioClipInfo.fromJson(item)).toList();
  }

  Future<Object?> _get(String action, [Map<String, String>? params]) async {
    final response = await http
        .get(_uri(action, params))
        .timeout(_requestTimeout, onTimeout: _timeout);
    final envelope = _decodeEnvelope(response);
    return envelope['data'];
  }

  Never _timeout() {
    throw TimeoutException(
      'เชื่อมต่อ API ไม่ได้ กรุณาตรวจว่า Apache/MySQL เปิดอยู่',
    );
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (response.statusCode >= 400) {
        throw ApiException('API error ${response.statusCode}');
      }
      throw const FormatException('Invalid API response');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid API response');
    }
    if (response.statusCode >= 400 || decoded['ok'] != true) {
      throw ApiException('${decoded['error'] ?? 'API error'}');
    }
    return decoded;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
