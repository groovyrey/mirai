import 'dart:convert';

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
  });

  final String playUrl;

  /// 'doodstream' for direct MP4; 'echovideo' | 'byse' | 'dood' | 'unknown'
  /// when the worker could only hand back an embed page.
  final String provider;
  final String quality;
  final bool embedMode;
  final String? note;

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
}