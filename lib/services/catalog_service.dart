import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/anime_item.dart';

class CatalogFailure implements Exception {
  const CatalogFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to the Mirai catalog backend (worker8652 `/api/aniwaves/*`).
class CatalogService {
  CatalogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Uri _url(String path, [Map<String, String>? query]) {
    final base = AppConfig.resolverBase.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<List<AnimeItem>> _items(String path, [Map<String, String>? query]) async {
    final http.Response res;
    try {
      res = await _client.get(_url(path, query)).timeout(_timeout);
    } catch (_) {
      throw const CatalogFailure('Failed to reach the catalog.');
    }
    if (res.statusCode != 200) {
      throw CatalogFailure('Catalog error ${res.statusCode}.');
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic> || data['ok'] != true) {
      final message = data is Map<String, dynamic>
          ? (data['error'] as String?) ?? 'Nothing here.'
          : 'Nothing here.';
      throw CatalogFailure(message);
    }
    final list = data['results'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic>)
          AnimeItem.fromJson(e)
        else if (e is Map)
          AnimeItem.fromJson(e.cast<String, dynamic>()),
    ];
  }

  /// "Trending" is the home rail; [mode] selects trending|updated|newest.
  Future<List<AnimeItem>> rail(String mode, {int page = 1}) =>
      _items('/list', {'mode': mode, 'page': '$page'});

  Future<List<AnimeItem>> search(String query) =>
      _items('/search', {'q': query});

  /// Full detail including episodes for one anime.
  Future<AnimeDetail> detail(int id, String slug) async {
    final http.Response res;
    try {
      res = await _client
          .get(_url('/detail', {'id': '$id', 'slug': slug}))
          .timeout(_timeout);
    } catch (_) {
      throw const CatalogFailure('Failed to reach the catalog.');
    }
    if (res.statusCode != 200) {
      throw CatalogFailure('Catalog error ${res.statusCode}.');
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic> || data['ok'] != true) {
      throw CatalogFailure('Nothing here.');
    }
    return AnimeDetail.fromJson(data);
  }
}