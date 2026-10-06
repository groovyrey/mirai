import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single published release plus its changelog and installable assets.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.url,
    this.notes = '',
    this.publishedAt,
    this.prerelease = false,
    this.assets = const <ReleaseAsset>[],
  });

  final String version;
  final String url;

  /// Release body as written on GitHub, rendered by the updates screen.
  final String notes;
  final DateTime? publishedAt;
  final bool prerelease;
  final List<ReleaseAsset> assets;

  bool get hasNotes => notes.trim().isNotEmpty;

  String get publishedLabel {
    final at = publishedAt;
    if (at == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[at.month - 1]} ${at.day}, ${at.year}';
  }
}

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    this.sizeBytes = 0,
    this.downloads = 0,
  });

  final String name;
  final String url;
  final int sizeBytes;
  final int downloads;

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    final mb = sizeBytes / (1024 * 1024);
    return mb >= 10 ? '${mb.round()} MB' : '${mb.toStringAsFixed(1)} MB';
  }
}

/// Reads Mirai's GitHub releases feed and parses it into [ReleaseInfo].
///
/// One fetch path and one cache window, so the settings banner and the updates
/// screen never re-hit the API for data the other already loaded. Cache state
/// is per instance; callers should hold one checker for the app's lifetime.
class VersionChecker {
  VersionChecker({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const _feedEndpoint =
      'https://api.github.com/repos/groovyrey/mirai/releases?per_page=20';

  static const _cacheDuration = Duration(hours: 24);
  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'mirai-android',
  };

  String _cachedFeed = '';
  DateTime _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Every published release on the requested channel, newest first.
  ///
  /// Returns an empty list when [enabled] is false so an opted-out user never
  /// touches the network.
  Future<List<ReleaseInfo>> releases({
    bool includePrerelease = false,
    bool enabled = true,
    bool forceRefresh = false,
    Duration cacheFor = _cacheDuration,
  }) async {
    if (!enabled) return const <ReleaseInfo>[];
    final raw = await _feed(forceRefresh: forceRefresh, cacheFor: cacheFor);
    final parsed = _parse(raw);
    return parsed.where((r) => includePrerelease || !r.prerelease).toList()
      ..sort((a, b) =>
          (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)));
  }

  /// The newest release on the requested channel, if one is published.
  Future<ReleaseInfo?> latest({
    bool includePrerelease = false,
    bool enabled = true,
    bool forceRefresh = false,
    Duration cacheFor = _cacheDuration,
  }) async {
    final all = await releases(
      includePrerelease: includePrerelease,
      enabled: enabled,
      forceRefresh: forceRefresh,
      cacheFor: cacheFor,
    );
    return all.isEmpty ? null : all.first;
  }

  Future<String> _feed({
    required bool forceRefresh,
    required Duration cacheFor,
  }) async {
    if (!forceRefresh &&
        _cachedFeed.isNotEmpty &&
        DateTime.now().difference(_cachedAt) < cacheFor) {
      return _cachedFeed;
    }
    try {
      final res = await (_client ?? http.Client())
          .get(Uri.parse(_feedEndpoint), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return _cachedFeed;
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return _cachedFeed;
      _cachedFeed = jsonEncode(decoded);
      _cachedAt = DateTime.now();
      return _cachedFeed;
    } catch (_) {
      return _cachedFeed;
    }
  }

  static List<ReleaseInfo> _parse(String raw) {
    if (raw.isEmpty) return const <ReleaseInfo>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ReleaseInfo>[];
      final out = <ReleaseInfo>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final tag = item['tag_name'];
        if (tag is! String || tag.isEmpty) continue;
        if (item['draft'] == true) continue;
        final url = item['html_url'];
        out.add(ReleaseInfo(
          version: tag.replaceFirst(RegExp('^v'), ''),
          url: url is String ? url : _feedEndpoint,
          notes: item['body'] is String ? item['body'] as String : '',
          publishedAt: DateTime.tryParse('${item['published_at']}'),
          prerelease: item['prerelease'] == true,
          assets: _parseAssets(item['assets']),
        ));
      }
      return out;
    } catch (_) {
      return const <ReleaseInfo>[];
    }
  }

  static List<ReleaseAsset> _parseAssets(Object? raw) {
    if (raw is! List) return const <ReleaseAsset>[];
    final out = <ReleaseAsset>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name'];
      final url = item['browser_download_url'];
      if (name is! String || url is! String) continue;
      final size = item['size'];
      final downloads = item['download_count'];
      out.add(ReleaseAsset(
        name: name,
        url: url,
        sizeBytes: size is int ? size : 0,
        downloads: downloads is int ? downloads : 0,
      ));
    }
    return out;
  }
}
