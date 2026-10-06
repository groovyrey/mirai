import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/semver.dart';

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
    this.updatedAt,
  });

  final String name;
  final String url;
  final int sizeBytes;
  final int downloads;
  final DateTime? updatedAt;

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

  /// A plain `1.2.0` or `1.2.0-beta.3`, i.e. a tag that names a version.
  static final _versionPattern =
      RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$');

  /// Matches the APK names the build workflow produces.
  ///
  /// `Mirai-1.3.0-beta.apk` and `Mirai-1.2.0-arm64.apk`. The trailing `.apk`
  /// anchor keeps the version group from swallowing the extension, and the
  /// arch suffix is stripped afterwards by [_versionFromAssets].
  static final _assetPattern = RegExp(
    r'^Mirai-(\d+\.\d+\.\d+(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?)\.apk$',
  );

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
  ///
  /// Ranked by version rather than publish date so `1.3.0-beta` is offered to
  /// someone on 1.2.0 even though no stable tag for it exists yet.
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
    if (all.isEmpty) return null;
    ReleaseInfo? best;
    for (final release in all) {
      if (best == null ||
          SemVer(release.version) > SemVer(best.version)) {
        best = release;
      }
    }
    return best;
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
        final assets = _parseAssets(item['assets']);
        final prerelease = item['prerelease'] == true;
        // GitHub never moves a release's own published_at, so the rolling beta
        // stays pinned to the day it was first created no matter how often its
        // APK is replaced. Its real recency is the newest asset upload.
        final published =
            DateTime.tryParse('${item['published_at']}');
        final newestAsset = _newestAssetTime(assets);
        final derived = _versionFromTag(tag) ?? _versionFromAssets(assets);
        if (derived == null) continue;
        out.add(ReleaseInfo(
          version: derived,
          url: url is String ? url : _feedEndpoint,
          notes: item['body'] is String ? item['body'] as String : '',
          publishedAt: _latest(published, newestAsset),
          prerelease: prerelease,
          assets: assets,
        ));
      }
      return out;
    } catch (_) {
      return const <ReleaseInfo>[];
    }
  }

  /// Pulls a usable version out of a tag, or null when the tag carries no
  /// version at all.
  static String? _versionFromTag(String tag) {
    final stripped = tag.replaceFirst(RegExp('^v'), '');
    return _versionPattern.hasMatch(stripped) ? stripped : null;
  }

  /// Recovers the version of a rolling pre-release from its newest APK name.
  ///
  /// The build workflow publishes those under the fixed tag `beta`, which is
  /// not a semver, but names the asset `Mirai-1.3.0-beta.apk`. Without this the
  /// beta channel parses the release as 0.0.0 and never announces it.
  static String? _versionFromAssets(List<ReleaseAsset> assets) {
    String? best;
    for (final asset in assets) {
      final match = _assetPattern.firstMatch(asset.name);
      if (match == null) continue;
      // `arm64` is the ABI, not a pre-release tag.
      final candidate =
          match.group(1)!.replaceFirst(RegExp(r'-arm64$'), '');
      if (best == null || SemVer(candidate) > SemVer(best)) best = candidate;
    }
    return best;
  }

  static DateTime? _newestAssetTime(List<ReleaseAsset> assets) {
    DateTime? newest;
    for (final asset in assets) {
      final at = asset.updatedAt;
      if (at == null) continue;
      if (newest == null || at.isAfter(newest)) newest = at;
    }
    return newest;
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
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
        updatedAt: DateTime.tryParse('${item['updated_at']}'),
      ));
    }
    return out;
  }
}
