import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/saved.dart';
import '../services/version_checker.dart';
import '../services/watch_history.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';

/// More: settings and about in one editorial column. The update banner and the
/// version-settings row live here; the header in the shell shows the version.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final VersionChecker _checker = VersionChecker();
  VersionInfo? _update;

  @override
  void initState() {
    super.initState();
    _maybedCheck();
  }

  Future<void> _maybedCheck() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final state = context.read<AppState>();
    final info = await _checker.check(
      includePrerelease: state.updateChannel == UpdateChannel.beta,
      enabled: state.autoCheckUpdates,
    );
    if (!mounted) return;
    if (info != null) setState(() => _update = info);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
            child: Text(
              'MORE',
              style: context.appTextTheme.displayMedium?.copyWith(
                color: context.appOnSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_update != null) _banner(context, _update!),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: SectionLabel(text: 'PLAYBACK'),
          ),
          _SwitchTile(
            title: 'Keep screen awake',
            value: state.keepAwake,
            onChanged: (v) async {
              await state.setKeepAwake(v);
              if (v) {
                await WakelockPlus.enable();
              } else {
                await WakelockPlus.disable();
              }
            },
          ),
          _SwitchTile(
            title: 'Hardware decode',
            subtitle: 'Faster playback on capable devices',
            value: state.hardwareDecode,
            onChanged: state.setHardwareDecode,
          ),
          _SliderTile(
            title: 'Default speed',
            value: state.defaultSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            label: '${state.defaultSpeed.toStringAsFixed(1)}x',
            onChanged: state.setDefaultSpeed,
          ),
          _ListTile(
            title: 'Audio',
            subtitle: state.audioMode == AudioMode.dub ? 'Dub first' : 'Sub first',
            onTap: () => _pickAudio(context, state),
          ),
          _Select(
            title: 'Update channel',
            value: state.updateChannel.label,
            onTap: () => _pickChannel(context, state),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: SectionLabel(text: 'ACCOUNT & DATA'),
          ),
          _ListTile(
            title: 'Saved titles',
            subtitle: '${context.read<Saved>().items.length} titles in your queue',
            onTap: () => _clearSaved(context),
          ),
          _ListTile(
            title: 'Watch history',
            subtitle: '${context.read<WatchHistory>().entries.length} entries',
            onTap: () => _clearHistory(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: SectionLabel(text: 'ABOUT'),
          ),
          _ListTile(
            title: 'Source',
            subtitle: 'github.com/groovyrey/mirai',
            onTap: () => _open('https://github.com/groovyrey/mirai'),
          ),
          _ListTile(
            title: 'Report a problem',
            subtitle: 'Open the issue tracker',
            onTap: () =>
                _open('https://github.com/groovyrey/mirai/issues'),
          ),
          _ListTile(
            title: 'Privacy',
            subtitle: 'Mirai stores everything on your device',
            onTap: () => _open('https://github.com/groovyrey/mirai'),
          ),
          const SizedBox(height: 24),
          Center(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '·';
                return Text(
                  'MIRAI v$version',
                  style: context.appTextTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: context.appOnSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context, VersionInfo update) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appAccentSoft,
          border: Border.all(color: context.appAccent),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UPDATE AVAILABLE',
              style: context.appTextTheme.labelSmall?.copyWith(
                color: context.appOnAccent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'v${update.version} is out. Grab it from the release page.',
              style: context.appTextTheme.bodyLarge?.copyWith(
                color: context.appOnAccent,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.appOnAccent,
                padding: EdgeInsets.zero,
              ),
              onPressed: () => _open(
                'https://github.com/groovyrey/mirai/releases/latest',
              ),
              child: const Text('GO TO RELEASES'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAudio(BuildContext context, AppState state) async {
    final choice = await showModalBottomSheet<AudioMode>(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Sub first'),
              onTap: () => Navigator.pop(context, AudioMode.sub),
            ),
            ListTile(
              title: const Text('Dub first'),
              onTap: () => Navigator.pop(context, AudioMode.dub),
            ),
          ],
        ),
      ),
    );
    if (choice != null) await state.setAudioMode(choice);
  }

  Future<void> _pickChannel(BuildContext context, AppState state) async {
    final choice = await showModalBottomSheet<UpdateChannel>(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final channel in UpdateChannel.values)
              ListTile(
                title: Text(channel.label),
                onTap: () => Navigator.pop(context, channel),
              ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await state.setUpdateChannel(choice);
      setState(() => _update = null);
    }
  }

  Future<void> _clearSaved(BuildContext context) async {
    final saved = context.read<Saved>();
    if (saved.items.isEmpty) return;
    final yes = await _confirm(context, 'Clear your saved titles?');
    if (yes) await saved.clear();
  }

  Future<void> _clearHistory(BuildContext context) async {
    final history = context.read<WatchHistory>();
    if (history.entries.isEmpty) return;
    final yes = await _confirm(context, 'Clear watch history?');
    if (yes) await history.clear();
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'CONFIRM',
          style: context.appTextTheme.labelSmall?.copyWith(
            letterSpacing: 2,
          ),
        ),
        content: Text(message, style: context.appTextTheme.bodyLarge),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('YES', style: TextStyle(color: context.appAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _MobileTileBase extends StatelessWidget {
  const _MobileTileBase({required this.title, this.subtitle, this.onTap});
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.appTextTheme.titleMedium?.copyWith(
                      color: context.appOnSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.appTextTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: context.appOnSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({required this.title, this.subtitle, this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MobileTileBase(title: title, subtitle: subtitle, onTap: onTap),
        const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({required this.title, required this.value, required this.onTap});

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MobileTileBase(
          title: title,
          onTap: onTap,
          subtitle: value,
        ),
        const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.appTextTheme.titleMedium?.copyWith(
                        color: context.appOnSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.appTextTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                activeTrackColor: context.appAccent,
                activeThumbColor: context.appOnAccent,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.appTextTheme.titleMedium?.copyWith(
                    color: context.appOnSurface,
                  ),
                ),
              ),
              Text(
                label,
                style: context.appTextTheme.labelSmall?.copyWith(
                  color: context.appAccent,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: context.appAccent,
          inactiveColor: context.appOutline,
          onChanged: onChanged,
        ),
        const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}