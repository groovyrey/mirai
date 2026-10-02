import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Default audio for new playbacks: subtitled or dubbed.
enum AudioMode { sub, dub }

/// Which release channel the update banner listens to.
enum UpdateChannel {
  stable('Stable'),
  beta('Beta');

  const UpdateChannel(this.label);
  final String label;
}

class AppState extends ChangeNotifier {
  static const _themeModeKey = 'theme_mode';
  static const _autoCheckKey = 'auto_check_updates';
  static const _updateChannelKey = 'update_channel';
  static const _keepAwakeKey = 'keep_screen_awake';
  static const _hardwareDecodeKey = 'hardware_decode';
  static const _defaultSpeedKey = 'default_speed';
  static const _audioModeKey = 'audio_mode';
  static const _resolverOverrideKey = 'resolver_base_override';
  static const _preferredSvKey = 'preferred_source_v1';

  static const _settingsKeys = [
    _themeModeKey,
    _autoCheckKey,
    _updateChannelKey,
    _keepAwakeKey,
    _hardwareDecodeKey,
    _defaultSpeedKey,
    _audioModeKey,
    _resolverOverrideKey,
    _preferredSvKey,
  ];

  ThemeMode _themeMode = ThemeMode.system;
  bool _autoCheckUpdates = true;
  UpdateChannel _updateChannel = UpdateChannel.stable;
  bool _keepAwake = true;
  bool _hardwareDecode = false;
  double _defaultSpeed = 1.0;
  AudioMode _audioMode = AudioMode.sub;
  String _resolverOverride = '';
  final Map<String, int> _preferredSv = <String, int>{};

  ThemeMode get themeMode => _themeMode;
  bool get autoCheckUpdates => _autoCheckUpdates;
  UpdateChannel get updateChannel => _updateChannel;
  bool get keepAwake => _keepAwake;
  bool get hardwareDecode => _hardwareDecode;
  double get defaultSpeed => _defaultSpeed;
  AudioMode get audioMode => _audioMode;
  String get resolverOverride => _resolverOverride;

  /// The server the user pinned for a given anime id, if any.
  int? preferredSv(String animeId) => _preferredSv[animeId];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _autoCheckUpdates = prefs.getBool(_autoCheckKey) ?? true;
    _updateChannel = UpdateChannel.values.firstWhere(
      (value) => value.name == prefs.getString(_updateChannelKey),
      orElse: () => UpdateChannel.stable,
    );
    _keepAwake = prefs.getBool(_keepAwakeKey) ?? true;
    _hardwareDecode = prefs.getBool(_hardwareDecodeKey) ?? false;
    _defaultSpeed =
        prefs.getDouble(_defaultSpeedKey)?.clamp(0.5, 2.0) ?? 1.0;
    _audioMode = prefs.getString(_audioModeKey) == 'dub'
        ? AudioMode.dub
        : AudioMode.sub;
    _resolverOverride = prefs.getString(_resolverOverrideKey) ?? '';
    AppConfig.aniwavesBaseOverride = _resolverOverride;
    final rawSvPrefs = prefs.getString(_preferredSvKey);
    if (rawSvPrefs != null && rawSvPrefs.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSvPrefs);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            if (entry.value is num) {
              _preferredSv[entry.key] = (entry.value as num).toInt();
            }
          }
        }
      } catch (_) {
        // corrupted preference, treated as unset
      }
    }
    notifyListeners();
  }

  Future<void> cycleTheme() async {
    final next = switch (themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    _themeMode = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, next.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<void> setAutoCheckUpdates(bool enabled) async {
    _autoCheckUpdates = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckKey, enabled);
  }

  Future<void> setUpdateChannel(UpdateChannel value) async {
    _updateChannel = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_updateChannelKey, value.name);
  }

  Future<void> setKeepAwake(bool enabled) async {
    _keepAwake = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepAwakeKey, enabled);
  }

  Future<void> setHardwareDecode(bool enabled) async {
    _hardwareDecode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hardwareDecodeKey, enabled);
  }

  Future<void> setDefaultSpeed(double speed) async {
    _defaultSpeed = speed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultSpeedKey, speed);
  }

  Future<void> setAudioMode(AudioMode mode) async {
    _audioMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioModeKey, mode.name);
  }

  Future<void> setResolverOverride(String value) async {
    _resolverOverride = value.trim();
    AppConfig.aniwavesBaseOverride = _resolverOverride;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resolverOverrideKey, _resolverOverride);
  }

  /// Pins [sv] as the preferred server for [animeId]; [sv] null clears it.
  Future<void> setPreferredSv(String animeId, int? sv) async {
    if (sv == null) {
      _preferredSv.remove(animeId);
    } else {
      _preferredSv[animeId] = sv;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredSvKey, jsonEncode(_preferredSv));
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _settingsKeys) {
      await prefs.remove(key);
    }
    _themeMode = ThemeMode.system;
    _autoCheckUpdates = true;
    _updateChannel = UpdateChannel.stable;
    _keepAwake = true;
    _hardwareDecode = false;
    _defaultSpeed = 1.0;
    _audioMode = AudioMode.sub;
    _resolverOverride = '';
    _preferredSv.clear();
    AppConfig.aniwavesBaseOverride = '';
    notifyListeners();
  }
}