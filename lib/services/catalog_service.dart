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

  // In-memory cache with stale-while-revalidate. The worker already caches
  // these endpoints, but a session-local snapshot avoids the round trip when
  // the home rails reload on every open (and yields an instant first frame).
  static final Map<String, CachedEntry> _cache = {};
  static const _ttl = Duration(minutes: 10);
  static const _swr = Duration(minutes: 5);

  Uri _url(String path, [Map<String, String>? query]) {
    final base = AppConfig.resolverBase.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  static List<AnimeItem>? _peek(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    if (cached.storedAt.isBefore(DateTime.now().subtract(_ttl + _swr))) {
      _cache.remove(key);
      return null;
    }
    return cached.items;
  }

  static void _store(String key, List<AnimeItem> items) {
    _cache[key] = CachedEntry(items: items, storedAt: DateTime.now());
  }

  Future<List<AnimeItem>> _items(String path, [Map<String, String>? query]) async {
    final key = Uri(path: path, queryParameters: query).toString();
    final hit = _peek(key);
    if (hit != null) return hit;
    final http.Response res;
    try {
      res = await _client.get(_url(path, query)).timeout(_timeout);
    } catch (_) {
      // Serve a stale copy if the network call failed outright.
      final stale = _cache[key];
      if (stale != null) return stale.items;
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
    final items = [
      for (final e in list)
        if (e is Map<String, dynamic>)
          AnimeItem.fromJson(e)
        else if (e is Map)
          AnimeItem.fromJson(e.cast<String, dynamic>()),
    ];
    _store(key, items);
    return items;
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

/// A memoized rail result with its creation time (for TTL-based reuse).
class CachedEntry {
  const CachedEntry({required this.items, required this.storedAt});

  final List<AnimeItem> items;
  final DateTime storedAt;
}