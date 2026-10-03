import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime_item.dart';

/// A watched episode with its stored position, for "continue watching".
class HistoryEntry {
  const HistoryEntry({
    required this.item,
    required this.ep,
    required this.dub,
    required this.resumePosition,
    required this.duration,
    required this.watchedAt,
  });

  final AnimeItem item;
  final int ep;
  final bool dub;
  final int resumePosition;
  final int duration;
  final int watchedAt;

  double get progress {
    if (duration <= 0) return 0;
    return (resumePosition / duration).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'ep': ep,
        'dub': dub,
        'resumePosition': resumePosition,
        'duration': duration,
        'watchedAt': watchedAt,
      };

  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final item = json['item'];
    if (item is! Map) return null;
    return HistoryEntry(
      item: AnimeItem.fromJson(item.cast<String, dynamic>()),
      ep: json['ep'] as int? ?? 1,
      dub: json['dub'] == true,
      resumePosition: json['resumePosition'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      watchedAt: json['watchedAt'] as int? ?? 0,
    );
  }
}

/// Watch history with resume positions, persisted locally.
class WatchHistory extends ChangeNotifier {
  WatchHistory._();
  static final WatchHistory instance = WatchHistory._();

  static const _key = 'mirai:history';
  static const _limit = 50;

  final List<HistoryEntry> _entries = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _entries.addAll(_decode(prefs.getString(_key) ?? ''));
    } catch (_) {
      // Nothing to load.
    }
    _loaded = true;
    notifyListeners();
  }

  List<HistoryEntry> get entries =>
      List.unmodifiable([..._entries]..sort((a, b) => b.watchedAt - a.watchedAt));

  HistoryEntry? entryFor(int id, int ep) {
    for (final e in _entries) {
      if (e.item.id == id && e.ep == ep) return e;
    }
    return null;
  }

  /// Records progress; entries near completion are dropped so "continue
  /// watching" only surfaces genuinely unfinished episodes.
  Future<void> update({
    required AnimeItem item,
    required int ep,
    required bool dub,
    required Duration position,
    required Duration duration,
  }) async {
    await ensureLoaded();
    if (position >= const Duration(seconds: 5) &&
        duration > Duration.zero &&
        position >= duration - const Duration(seconds: 15)) {
      await clearEntry(item.id, ep);
      return;
    }
    _entries.removeWhere(
      (e) => e.item.id == item.id && e.ep == ep,
    );
    _entries.insert(
      0,
      HistoryEntry(
        item: item,
        ep: ep,
        dub: dub,
        resumePosition: position.inMilliseconds,
        duration: duration.inMilliseconds,
        watchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> clearEntry(int id, int ep) async {
    await ensureLoaded();
    _entries.removeWhere((e) => e.item.id == id && e.ep == ep);
    notifyListeners();
    await _persist();
  }

  Duration resumeFor(AnimeItem item, int ep) {
    final e = entryFor(item.id, ep);
    if (e == null) return Duration.zero;
    return Duration(milliseconds: e.resumePosition);
  }

  Future<void> clear() async {
    await ensureLoaded();
    _entries.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final e in _entries.take(_limit)) e.toJson()]),
      );
    } catch (_) {
      // Best-effort persistence.
    }
  }

  List<HistoryEntry> _decode(String raw) {
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((e) => e is Map
              ? HistoryEntry.fromJson(e.cast<String, dynamic>())
              : null)
          .whereType<HistoryEntry>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}