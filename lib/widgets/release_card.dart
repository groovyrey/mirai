import 'package:flutter/material.dart';

import '../services/version_checker.dart';
import '../theme/app_theme.dart';
import 'release_notes.dart';

/// One pending release: version, date, full changelog, and install links.
///
/// The newest pending release renders with the accent treatment so the drawer
/// entry and the banner both point at one obvious target.
class ReleaseCard extends StatelessWidget {
  const ReleaseCard({
    super.key,
    required this.release,
    required this.isNewest,
    required this.onOpen,
  });

  final ReleaseInfo release;
  final bool isNewest;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final notesStyle = context.appTextTheme.bodyMedium
        ?.copyWith(color: context.appOnSurfaceVariant, height: 1.45);
    final asset = release.assets.isEmpty ? null : release.assets.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isNewest ? context.appAccentSoft : context.appSurface,
        border: Border.all(
          color: isNewest ? context.appAccent : context.appOutline,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          if (release.hasNotes) ...[
            const SizedBox(height: 14),
            ReleaseNotesView(body: release.notes, textStyle: notesStyle),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              ReleaseAction(
                label: asset == null ? 'RELEASE PAGE' : 'DOWNLOAD',
                onTap: () => onOpen(asset?.url ?? release.url),
                primary: isNewest,
              ),
              if (release.assets.length > 1)
                ReleaseAction(
                  label: 'ALL FILES',
                  onTap: () => onOpen(release.url),
                  primary: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final color = isNewest ? context.appOnAccentSoft : context.appOnSurface;
    return Row(
      children: [
        Text(
          'v${release.version}',
          style: context.appTextTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (release.prerelease)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'BETA',
              style: context.appTextTheme.labelSmall?.copyWith(
                color: color,
                letterSpacing: 1.5,
              ),
            ),
          ),
        if (release.publishedLabel.isNotEmpty)
          Text(
            release.publishedLabel,
            style: context.appTextTheme.labelSmall?.copyWith(
              color: color,
              letterSpacing: 0.5,
            ),
          ),
      ],
    );
  }
}

/// A tappable underlined action, matching the app's quiet link styling.
class ReleaseAction extends StatelessWidget {
  const ReleaseAction({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? context.appOnAccentSoft : context.appOnSurface;
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: context.appTextTheme.labelSmall?.copyWith(
          color: color,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}

/// One line of release history: version, date, and asset size.
class ReleaseHistoryRow extends StatelessWidget {
  const ReleaseHistoryRow({
    super.key,
    required this.release,
    required this.current,
    required this.onTap,
  });

  final ReleaseInfo release;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = context.appTextTheme.labelSmall
        ?.copyWith(color: context.appOnSurfaceVariant);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Text(
              'v${release.version}',
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: current ? context.appAccent : context.appOnSurface,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(release.publishedLabel, style: muted)),
            if (release.assets.isNotEmpty)
              Text(release.assets.first.sizeLabel, style: muted),
          ],
        ),
      ),
    );
  }
}

/// Shown when the installed build is already the newest release.
class UpToDateRow extends StatelessWidget {
  const UpToDateRow({super.key, required this.installed});

  final String installed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: context.appOutline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Text(
            'v$installed',
            style: context.appTextTheme.titleLarge?.copyWith(
              color: context.appOnSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nothing new to install.',
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appOnSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}