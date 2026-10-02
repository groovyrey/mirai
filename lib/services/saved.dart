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