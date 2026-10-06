import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/mirai_wordmark.dart';

/// About Mirai: a broadcast-identification style hero, a two-column feature
/// grid, the playback sources, and a quiet developer footer. Intentionally a
/// different shape from Kumi's centered card stack.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _githubUrl = 'https://github.com/groovyrey';
  static const _email = 'reymartcenteno03@gmail.com';

  static const _purposeBody = 'Mirai is a lightweight streaming app built for '
      'anime nights: search the catalog, pick a title, and start watching in '
      'seconds. No accounts, no ads, no noise.';

  static final _features = [
    (
      PhosphorIcons.filmSlate(),
      'Unified catalog',
      'Trending, seasonal, and saved titles in one place.',
    ),
    (
      PhosphorIcons.magnifyingGlass(),
      'Instant search',
      'One field finds the whole catalog in a keystroke.',
    ),
    (
      PhosphorIcons.playCircle(),
      'Native player',
      'Hardware-accelerated playback with auto recovery.',
    ),
    (
      PhosphorIcons.deviceMobile(),
      'Late-night friendly',
      'Calm design that works in light and dark.',
    ),
  ];

  static final _sources = [
    (
      Icons.play_circle_outline_rounded,
      'DoodStream',
      'Primary native source',
      'NATIVE',
    ),
    (
      Icons.hd_rounded,
      'AniWatch',
      'ZokoAnime mirror with subtitles, switchable per episode',
      'NATIVE',
    ),
    (
      Icons.language_rounded,
      'Embed player',
      'Full-page fallback when a direct stream is down',
      'EMBED',
    ),
  ];

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: context.appOnSurfaceVariant,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    'ABOUT',
                    style: context.appTextTheme.labelSmall?.copyWith(
                      color: context.appAccent,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const MiraiWordmark(size: 30),
              const SizedBox(height: 24),
              Container(width: 34, height: 4, color: context.appAccent),
              const SizedBox(height: 10),
              Text(
                'Anime, on your terms.',
                style: context.appTextTheme.displayMedium?.copyWith(
                  color: context.appOnSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _purposeBody,
                style: context.appTextTheme.bodyLarge?.copyWith(
                  color: context.appOnSurfaceVariant,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 30),
              _sectionLabel(context, 'What Mirai does'),
              const SizedBox(height: 12),
              _featureGrid(context),
              const SizedBox(height: 30),
              _sectionLabel(context, 'Playback sources'),
              const SizedBox(height: 12),
              _sourceCard(context),
              const SizedBox(height: 34),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureGrid(BuildContext context) {
    final rows = (_features.length + 1) ~/ 2;
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _featureTile(context, _features[r * 2])),
              const SizedBox(width: 10),
              Expanded(
                child: r * 2 + 1 < _features.length
                    ? _featureTile(context, _features[r * 2 + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _featureTile(
    BuildContext context,
    (IconData, String, String) feature,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.appOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appAccentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.$1, size: 20, color: context.appOnAccentSoft),
          ),
          const SizedBox(height: 12),
          Text(
            feature.$2,
            style: context.appTextTheme.titleSmall?.copyWith(
              color: context.appOnSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            feature.$3,
            style: context.appTextTheme.bodySmall?.copyWith(
              color: context.appOnSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.appOutline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _sources.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.appOutline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.appAccentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _sources[i].$1,
                      size: 18,
                      color: context.appOnAccentSoft,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sources[i].$2,
                          style: context.appTextTheme.titleMedium?.copyWith(
                            color: context.appOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _sources[i].$3,
                          style: context.appTextTheme.bodySmall?.copyWith(
                            color: context.appOnSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _sources[i].$4,
                    style: context.appTextTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      color: context.appAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Built free, open, and without trackers. If it helps you find a '
          'show tonight, that is enough.',
          textAlign: TextAlign.center,
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appOnSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Developed and maintained by Groovyrey',
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 6,
          children: [
            _textLink(context, 'GitHub', _githubUrl),
            _textLink(context, 'Email', 'mailto:$_email'),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Powered by aniwaves',
          style: context.appTextTheme.bodySmall?.copyWith(
            color: context.appOnSurfaceVariant,
          ),
        ),
        const _VersionCaption(),
      ],
    );
  }

  Widget _textLink(BuildContext context, String label, String url) {
    return GestureDetector(
      onTap: () => _open(url),
      child: Text(
        label,
        style: context.appTextTheme.bodyMedium?.copyWith(
          color: context.appAccent,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: context.appAccent.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: context.appTextTheme.titleLarge?.copyWith(
        color: context.appOnSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _VersionCaption extends StatelessWidget {
  const _VersionCaption();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data?.version ?? '';
        final build = snap.data?.buildNumber ?? '';
        if (version.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Version $version ($build)',
            style: context.appTextTheme.bodySmall?.copyWith(
              color: context.appOnSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        );
      },
    );
  }
}