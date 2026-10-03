import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/anime_item.dart';

class ResolveFailure implements Exception {
  const ResolveFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A resolved playback source for one anime episode.
class ResolvedSource {
  const ResolvedSource({
    required this.playUrl,
    required this.provider,
    required this.quality,
    required this.embedMode,
    this.note,
    this.httpHeaders,
  });

  final String playUrl;

  /// 'doodstream' for direct MP4; 'echovideo' | 'byse' | 'dood' | 'unknown'
  /// when the worker could only hand back an embed page.
  final String provider;
  final String quality;
  final bool embedMode;
  final String? note;

  /// Extra request headers to attach to the media fetch. Used for direct CDN
  /// playback where the upstream gates on a mobile UA.
  final Map<String, String>? httpHeaders;

  static ResolvedSource? tryFromJson(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    if (data['ok'] != true) return null;
    final playUrl = data['playUrl'];
    if (playUrl is! String || playUrl.isEmpty) return null;
    final provider = (data['provider'] as String? ?? 'unknown').toLowerCase();
    final embedMode = switch (provider) {
      'doodstream' => false,
      _ => true,
    };
    return ResolvedSource(
      playUrl: playUrl,
      provider: provider,
      quality: data['quality'] as String? ?? 'auto',
      embedMode: embedMode,
      note: data['note'] as String?,
    );
  }
}

/// Resolves a playable URL for an aniwaves episode through worker8652.
///
/// [dub] requests a dubbed server when the episode has one. [embed] forces the
/// embed page (used by the source switcher) instead of a direct stream. [sv]
/// pins a specific aniwaves server. [proxy] routes direct streams through the
/// worker so media_kit receives them with the upstream's required headers.
class ResolverService {
  ResolverService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// aniwaves server id (as passed to the worker ?sv=) -> display name.
  static const serverNames = <int, String>{
    2: 'DoodStream',
  };

  static const serverOrder = [2];

  Future<ResolvedSource> resolve(
    AnimeItem item,
    int ep, {
    required bool dub,
    bool embed = false,
    int? sv,
    bool proxy = false,
  }) async {
    final base = AppConfig.resolverBase.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/resolve').replace(
      queryParameters: {
        'id': '${item.id}',
        'ep': '$ep',
        if (dub) 'dub': '1',
        if (embed) 'embed': '1',
        if (sv != null) 'sv': '$sv',
        if (proxy) 'proxy': '1',
      },
    );
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const ResolveFailure('Failed to reach the resolver.');
    }
    if (res.statusCode != 200) {
      throw ResolveFailure('Resolver error ${res.statusCode}.');
    }
    final data = jsonDecode(res.body);
    final source = ResolvedSource.tryFromJson(data);
    if (source == null) {
      final message = data is Map<String, dynamic>
          ? (data['error'] as String?) ?? 'Nothing playable.'
          : 'Nothing playable.';
      throw ResolveFailure(message);
    }
    return source;
  }

  /// Matches the mobile Chrome mobile UA that dood's CDN accepts.
  static const mobileUa =
      'Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  /// dood's embed and CDN pages expect a dood referer or they reject the video.
  static const doodReferer = 'https://playmogo.com/';

  static String _noise(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return List.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  /// Client-side DoodStream pass_md5 walk. aniwaves serves a myvidplay /
  /// playmogo `/e/` page, but dood answers the worker's Cloudflare egress with
  /// a Turnstile challenge (and its CDN blocks CF IPs outright), so direct MP4
  /// resolution happens from the phone: the embed page is fetched here, the
  /// player keys extracted, and the CDN URL built, mirroring dood's own
  /// makePlay(). The returned URL is played directly with a mobile UA (see
  /// [doodReferer]), which the CDN serves with a real 206 MP4.
  Future<String> resolveDoodNative(
    String embedUrl, {
    required int animeId,
    required int ep,
  }) async {
    final referer = 'https://aniwaves.ru/watch/$animeId?ep=$ep';
    const baseHeaders = {
      'User-Agent': mobileUa,
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    final embedRes = await _client
        .get(Uri.parse(embedUrl), headers: {...baseHeaders, 'Referer': referer})
        .timeout(const Duration(seconds: 20));
    if (embedRes.statusCode != 200) {
      throw const ResolveFailure('DoodStream embed unavailable.');
    }
    final keyMatch = RegExp(r'pass_md5/([A-Za-z0-9\-]+)/([A-Za-z0-9]+)')
        .firstMatch(embedRes.body);
    if (keyMatch == null) {
      throw const ResolveFailure('DoodStream page missing player keys.');
    }
    final finalUrl = embedRes.request?.url ?? Uri.parse(embedUrl);
    final host = finalUrl.origin;

    final pmRes = await _client
        .get(
          Uri.parse('$host/pass_md5/${keyMatch.group(1)}/${keyMatch.group(2)}'),
          headers: {
            ...baseHeaders,
            'Referer': finalUrl.toString(),
          },
        )
        .timeout(const Duration(seconds: 20));
    if (pmRes.statusCode != 200) {
      throw const ResolveFailure('DoodStream key endpoint failed.');
    }
    final cdn = pmRes.body.trim();
    if (!cdn.startsWith('https://')) {
      throw const ResolveFailure('DoodStream key endpoint returned no source.');
    }
    final token = keyMatch.group(2)!;
    final expiry = DateTime.now().millisecondsSinceEpoch;
    return '$cdn${_noise(10)}?token=$token&expiry=$expiry';
  }
}