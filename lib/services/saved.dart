import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime_item.dart';

/// A save with timestamps so the list can sort newest-first.
class SavedEntry {
  const SavedEntry({required this.detail, required this.addedAt});

  final AnimeDetail detail;
  final int addedAt;

  Map<String, dynamic> toJson() => {
        'detail': detail.toJson(),
        'added_at': addedAt,
      };

  static SavedEntry? fromJson(Map<String, dynamic> json) {
    final detail = json['detail'];
    if (detail is! Map) return null;
    return SavedEntry(
      detail: AnimeDetail.fromJson(detail.cast<String, dynamic>()),
      addedAt: json['added_at'] as int? ?? 0,
    );
  }
}

/// The user's saved titles ("My List"), persisted locally.
class Saved extends ChangeNotifier {
  Saved._();
  static final Saved instance = Saved._();

  static const _key = 'mirai:saved';
  static const _limit = 200;

  final List<SavedEntry> _entries = [];
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

  List<AnimeDetail> get items =>
      List.unmodifiable([for (final e in _entries) e.detail]);

  /// Raw entries with timestamps for sorting/display.
  List<SavedEntry> get entries =>
      List.unmodifiable(_entries);

  bool contains(int id) => _entries.any((e) => e.detail.item.id == id);

  Future<void> toggle(AnimeDetail detail) async {
    await ensureLoaded();
    final index =
        _entries.indexWhere((e) => e.detail.item.id == detail.item.id);
    if (index >= 0) {
      _entries.removeAt(index);
    } else {
      _entries.insert(
        0,
        SavedEntry(detail: detail, addedAt: DateTime.now().millisecondsSinceEpoch),
      );
    }
    notifyListeners();
    await _persist();
  }

  /// Replaces the stored snapshot for [detail]'s title when it is already in
  /// the queue. Detail screens call this after a fresh fetch so saved metadata
  /// does not stay frozen at the episode count seen when the title was added.
  Future<void> updateDetail(AnimeDetail detail) async {
    await ensureLoaded();
    final index =
        _entries.indexWhere((e) => e.detail.item.id == detail.item.id);
    if (index < 0 || _sameDetail(_entries[index].detail, detail)) return;
    _entries[index] = SavedEntry(
      detail: detail,
      addedAt: _entries[index].addedAt,
    );
    notifyListeners();
    await _persist();
  }

  /// Re-fetches the first [limit] saved entries with [fetch] (only airing
  /// titles when [onlyAiring] is set), ignoring failures so an offline start
  /// keeps serving the stored snapshot. Returns how many entries changed.
  Future<int> refreshDetails(
    Future<AnimeDetail> Function(AnimeItem item) fetch, {
    int limit = 20,
    int concurrency = 4,
    bool onlyAiring = false,
  }) async {
    await ensureLoaded();
    final targets = _entries
        .where(
          (e) =>
              !onlyAiring ||
              (e.detail.status ?? '').trim().toLowerCase() == 'airing',
        )
        .take(limit)
        .map((e) => e.detail.item)
        .toList();
    if (targets.isEmpty) return 0;
    final updates = <AnimeDetail>[];
    var next = 0;
    Future<void> worker() async {
      while (next < targets.length) {
        final item = targets[next++];
        try {
          updates.add(await fetch(item));
        } catch (_) {
          // Keep the stored snapshot when the title cannot be refreshed.
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency && i < targets.length; i++) worker(),
    ]);
    var changed = 0;
    for (final detail in updates) {
      final index =
          _entries.indexWhere((e) => e.detail.item.id == detail.item.id);
      if (index < 0 || _sameDetail(_entries[index].detail, detail)) continue;
      _entries[index] = SavedEntry(
        detail: detail,
        addedAt: _entries[index].addedAt,
      );
      changed++;
    }
    if (changed > 0) {
      notifyListeners();
      await _persist();
    }
    return changed;
  }

  static bool _sameDetail(AnimeDetail a, AnimeDetail b) =>
      a.item.title == b.item.title &&
      a.item.image == b.item.image &&
      a.status == b.status &&
      a.totalEps == b.totalEps &&
      a.subEps == b.subEps &&
      a.dubEps == b.dubEps &&
      a.episodes.length == b.episodes.length;

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

  List<SavedEntry> _decode(String raw) {
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((e) => e is Map
              ? SavedEntry.fromJson(e.cast<String, dynamic>())
              : null)
          .whereType<SavedEntry>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}