import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/mirai_wordmark.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _sourceUrl = 'https://github.com/groovyrey/mirai';
  static const _email = 'reymartcenteno03@gmail.com';

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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
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
                const SizedBox(width: 8),
                Text(
                  'About',
                  style: context.appTextTheme.titleLarge?.copyWith(
                    color: context.appOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const MiraiWordmark(size: 30),
            const SizedBox(height: 18),
            Text(
              'A free anime client for Android.',
              style: context.appTextTheme.titleMedium?.copyWith(
                color: context.appOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No accounts, no ads. Saved titles and watch progress stay on this device.',
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appOnSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Divider(height: 1, color: context.appOutline),
            _LinkRow(
              label: 'Source',
              value: 'GitHub',
              onTap: () => _open(_sourceUrl),
            ),
            Divider(height: 1, color: context.appOutline),
            _LinkRow(
              label: 'Contact',
              value: _email,
              onTap: () => _open('mailto:$_email'),
            ),
            Divider(height: 1, color: context.appOutline),
            const _VersionRow(),
            Divider(height: 1, color: context.appOutline),
            const SizedBox(height: 24),
            Text(
              'Catalog and playback data come from third-party sources.',
              style: context.appTextTheme.bodySmall?.copyWith(
                color: context.appOnSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Text(
              label,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appOnSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appOnSurface,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_outward_rounded,
              size: 16,
              color: context.appOnSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data?.version ?? '';
        final build = snap.data?.buildNumber ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Text(
                'Version',
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appOnSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                version.isEmpty ? '' : '$version ($build)',
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appOnSurface,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
