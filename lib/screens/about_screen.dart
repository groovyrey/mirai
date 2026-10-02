import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// About Mirai: purpose, sources, and the developer.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _githubUrl = 'https://github.com/groovyrey';
  static const _email = 'reymartcenteno03@gmail.com';

  static const _purposeLabel = 'Your anime streaming buddy.';
  static const _purposeBody = 'Mirai is a lightweight streaming app built for '
      'anime nights: search the catalog, pick a title, and start watching in '
      'seconds. No accounts, no ads, no noise.';

  static const _sourceNote = 'Mirai plays through publicly available sources '
      'hosted on aniwaves. Source availability varies; if one fails, Mirai '
      'falls back to the next working one.';

  static final _features = [
    (
      PhosphorIcons.filmSlate(),
      'Unified catalog',
      'Search trending, seasonal, and saved titles in one place.',
    ),
    (
      PhosphorIcons.magnifyingGlass(),
      'Instant search',
      'One field finds the whole catalog in a keystroke.',
    ),
    (
      PhosphorIcons.playCircle(),
      'Native + embed player',
      'Hardware-accelerated playback with a full-screen embed fallback.',
    ),
    (
      PhosphorIcons.deviceMobile(),
      'Made for late nights',
      'Warm, calm design that works in light and dark.',
    ),
  ];

  static final _sources = [
    (
      'DoodStream',
      Icons.play_circle_outline_rounded,
      'Primary native source',
    ),
    (
      'Vidplay',
      Icons.ondemand_video_outlined,
      'Embed backup',
    ),
    (
      'DatSaV',
      Icons.smart_display_outlined,
      'Embed backup',
    ),
    (
      'MyCloud',
      Icons.cloud_outlined,
      'Embed backup',
    ),
    (
      'BYFMS',
      Icons.video_collection_outlined,
      'Embed backup',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: MiraiMark(size: 88)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Mirai',
              style: context.appTextTheme.displayMedium?.copyWith(
                color: context.appOnSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Your Anime streaming buddy',
              style: context.appTextTheme.bodyLarge?.copyWith(
                color: context.appOnSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: _VersionPill()),
          const SizedBox(height: 30),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OUR PURPOSE',
                  style: context.appTextTheme.labelSmall?.copyWith(
                    color: context.appAccent,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _purposeLabel,
                  style: context.appTextTheme.headlineMedium?.copyWith(
                    color: context.appOnSurface,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _purposeBody,
                  style: context.appTextTheme.bodyLarge?.copyWith(
                    color: context.appOnSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _sectionLabel(context, 'What Mirai does'),
          const SizedBox(height: 12),
          SurfaceCard(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                for (var i = 0; i < _features.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.cardBorder),
                  _featureRow(context, _features[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),
          _sectionLabel(context, 'Playback sources'),
          const SizedBox(height: 12),
          SurfaceCard(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                for (var i = 0; i < _sources.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.cardBorder),
                  _sourceRow(context, _sources[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 34),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.info(), size: 18, color: context.appAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sourceNote,
                    style: context.appTextTheme.bodyMedium?.copyWith(
                      color: context.appOnSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                Text(
                  'Mirai is a hobby project — built free, open, and without '
                  'trackers. If it helps you find a show tonight, that is '
                  'enough.',
                  textAlign: TextAlign.center,
                  style: context.appTextTheme.bodyMedium?.copyWith(
                    color: context.appOnSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 16),
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
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _linkChip(
                        context, 'GitHub', PhosphorIcons.code(), _githubUrl),
                    _linkChip(context, 'Email', PhosphorIcons.envelope(),
                        'mailto:$_email'),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 12),
                Text(
                  'Powered by aniwaves',
                  style: context.appTextTheme.bodySmall?.copyWith(
                    color: context.appOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkChip(BuildContext context, String label, IconData icon, String url) {
    return InkWell(
      onTap: () => _open(url),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.appAccentSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: context.appAccent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: context.appAccent),
            const SizedBox(width: 7),
            Text(
              label,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(
      BuildContext context, (IconData, String, String) feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appAccentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.$1, size: 20, color: context.appAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.$2,
                  style: context.appTextTheme.titleMedium?.copyWith(
                    color: context.appOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  feature.$3,
                  style: context.appTextTheme.bodyMedium?.copyWith(
                    color: context.appOnSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceRow(BuildContext context, (String, IconData, String) source) {
    return Padding(
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
            child: Icon(source.$2, size: 18, color: context.appAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.$1,
                  style: context.appTextTheme.titleMedium?.copyWith(
                    color: context.appOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source.$3,
                  style: context.appTextTheme.bodySmall?.copyWith(
                    color: context.appOnSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class MiraiMark extends StatelessWidget {
  const MiraiMark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size * 0.18,
          height: size * 0.9,
          color: context.appAccent,
        ),
        SizedBox(width: size * 0.12),
        Text(
          'MIRAI',
          style: context.appTextTheme.displayMedium?.copyWith(
            fontSize: size,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0.02,
            color: context.appOnSurface,
          ),
        ),
      ],
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data?.version ?? '';
        final build = snap.data?.buildNumber ?? '';
        final label = version.isEmpty ? '' : 'Version $version ($build)';
        if (label.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.appSurfaceVariant.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            label,
            style: context.appTextTheme.labelSmall?.copyWith(
              color: context.appOnSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        );
      },
    );
  }
}