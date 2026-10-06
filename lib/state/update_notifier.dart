import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/version_checker.dart';
import '../utils/semver.dart';

/// Shared update availability for the drawer and the header.
///
/// The shell owns one instance and provides it below `AppState`, so the drawer
/// can reveal its Updates entry only while a newer stable release exists
/// without every screen running its own network check.
class UpdateNotifier extends ChangeNotifier {
  UpdateNotifier({VersionChecker? checker, String? installedVersion})
      : _checker = checker,
        _installedOverride = installedVersion;

  final VersionChecker _checker;

  /// Pins the installed version in tests; production reads PackageInfo.
  final String? _installedOverride;

  /// The checker backing this notifier, so the updates screen can reuse the
  /// same cache window instead of re-fetching what the banner already loaded.
  VersionChecker get checker => _checker;

  ReleaseInfo? _latest;
  String _installed = '';
  bool _checked = false;
  bool _checking = false;

  ReleaseInfo? get latest => _latest;
  String get installed => _installed;
  bool get hasUpdate => _latest != null;
  bool get checked => _checked;

  /// True when a newer build exists for the given channel.
  bool hasUpdateOn(bool includePrerelease) {
    final release = _latest;
    if (release == null) return false;
    if (release.prerelease && !includePrerelease) return false;
    if (_installed.isEmpty) return false;
    return SemVer(release.version) > SemVer(_installed);
  }

  /// Runs one check, reusing the version checker's cache unless [force].
  Future<void> check({
    required bool includePrerelease,
    required bool enabled,
    bool force = false,
  }) async {
    if (_checking) return;
    _checking = true;
    try {
      final release = await _checker.latest(
        includePrerelease: includePrerelease,
        enabled: enabled,
        forceRefresh: force,
      );
      _latest = release;
      _installed = await _installedVersion();
      _checked = true;
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  Future<String> _installedVersion() async {
    final pinned = _installedOverride;
    if (pinned != null) return pinned;
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }
}