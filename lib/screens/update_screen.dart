import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/version_checker.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/semver.dart';
import '../widgets/release_card.dart';

/// Standalone update screen: which release is installed, what came after it,
/// and the full changelog for every version the user skipped.
///
/// Opened from the drawer item that appears only while an update is pending,
/// but it also renders the up-to-date state so it stays usable as a manual
/// release history.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({
    super.key,
    required this.checker,
    this.installedVersion,
  });

  /// The screen is pushed as its own route, so the caller passes the shared
  /// checker in rather than reading it from a provider below the Navigator.
  final VersionChecker checker;

  /// Pins the installed build; production reads PackageInfo.
  final String? installedVersion;

  static Route<void> route(VersionChecker checker) =>
      MaterialPageRoute(builder: (_) => UpdateScreen(checker: checker));

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  static const _skippedSpacing = 28.0;

  late final VersionChecker _checker = widget.checker;

  List<ReleaseInfo> _pending = const <ReleaseInfo>[];
  List<ReleaseInfo> _history = const <ReleaseInfo>[];
  String _installed = '';
  bool _loading = true;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final state = context.read<AppState>();
    if (mounted) setState(() => _loading = true);
    final installed = await _installedVersion();
    // Opening this screen is an explicit request, so it fetches even when
    // automatic update checks are switched off in Settings.
    final all = await _checker.releases(
      includePrerelease: state.updateChannel == UpdateChannel.beta,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _pending = _pendingReleases(all, installed);
      _history = all;
      _loading = false;
    });
  }

  Future<String> _installedVersion() async {
    final pinned = widget.installedVersion;
    if (pinned != null) return pinned;
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  /// Releases newer than the installed build, newest first.
  List<ReleaseInfo> _pendingReleases(List<ReleaseInfo> all, String installed) {
    if (installed.isEmpty) return all;
    return releasesNewerThan(all, installed, (r) => r.version);
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upToDate = !_loading && _pending.isEmpty;
    final newest = _pending.isNotEmpty ? _pending.first : null;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true),
          color: context.appAccent,
          backgroundColor: context.appSurface,
          child: _loading
              ? const _LoadingBody()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  children: [
                    _bar(context),
                    const SizedBox(height: 22),
                    _headline(context, newest),
                    const SizedBox(height: _skippedSpacing),
                    if (upToDate)
                      UpToDateRow(installed: _installed)
                    else ...[
                      if (_pending.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            '${_pending.length} releases since v$_installed',
                            style: context.appTextTheme.labelSmall?.copyWith(
                              color: context.appOnSurfaceVariant,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      for (final release in _pending)
                        ReleaseCard(
                          release: release,
                          isNewest: release == newest,
                          onOpen: _open,
                        ),
                    ],
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: _skippedSpacing),
                      Text(
                        'ALL RELEASES',
                        style: context.appTextTheme.labelSmall?.copyWith(
                          color: context.appOnSurfaceVariant,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final release in _history)
                        ReleaseHistoryRow(
                          release: release,
                          current: release.version == _installed,
                          onTap: () => _open(release.url),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: context.appOnSurfaceVariant,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Spacer(),
        Text(
          'UPDATES',
          style: context.appTextTheme.labelSmall?.copyWith(
            color: context.appAccent,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _headline(BuildContext context, ReleaseInfo? newest) {
    final detail = newest == null
        ? (_installed.isEmpty
            ? ''
            : 'Mirai v$_installed is the latest build.')
        : (_installed.isEmpty
            ? 'v${newest.version} is ready to install.'
            : 'v$_installed is installed. v${newest.version} is ready.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          newest == null
              ? 'You are up to date'
              : 'Update available',
          style: context.appTextTheme.displayMedium?.copyWith(
            color: context.appOnSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        if (detail.isNotEmpty)
          Text(
            detail,
            style: context.appTextTheme.bodyMedium?.copyWith(
              color: context.appOnSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Text(
              'Checking for updates',
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appOnSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
