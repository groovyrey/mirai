import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../services/saved.dart';
import '../services/watch_history.dart';
import '../state/app_state.dart';
import '../state/update_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/mirai_wordmark.dart';
import 'about_screen.dart';
import 'browse_screen.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'trending_screen.dart';
import 'update_screen.dart';

/// Mirai's shell: a wordmark header with a drawer navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// Shared so the drawer, the settings banner, and the updates screen agree
  /// on one check and one cache window.
  final UpdateNotifier _updates = UpdateNotifier();

  static const _settingsIndex = 5;

  static const _tabs = [
    (icon: Icons.play_arrow_rounded, label: 'Home'),
    (icon: Icons.local_fire_department_rounded, label: 'Trending'),
    (icon: Icons.grid_view_rounded, label: 'Browse'),
    (icon: Icons.bookmark_rounded, label: 'Saved'),
    (icon: Icons.search_rounded, label: 'Find'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    // Deferred so the first frame lands before the network call starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      _updates.check(
        includePrerelease: state.updateChannel == UpdateChannel.beta,
        enabled: state.autoCheckUpdates,
      );
    });
  }

  @override
  void dispose() {
    _updates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: Saved.instance,
      child: ChangeNotifierProvider.value(
        value: WatchHistory.instance,
        child: ChangeNotifierProvider.value(
          value: _updates,
          child: _ShellScaffold(index: _index, onTab: _select),
        ),
      ),
    );
  }

  void _select(int i) => setState(() => _index = i);
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.index, required this.onTab});

  final int index;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final sections = [
      const HomeScreen(key: ValueKey('home')),
      const TrendingScreen(key: ValueKey('trending')),
      const BrowseScreen(key: ValueKey('browse')),
      const SavedScreen(key: ValueKey('saved')),
      const SearchScreen(key: ValueKey('search')),
      const SettingsScreen(key: ValueKey('settings')),
    ];

    return Scaffold(
      drawer: _Drawer(selected: index, onSelect: onTab),
      body: Column(
        children: [
          _Header(onTab: onTab),
          Expanded(child: sections[index]),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onTab});

  final ValueChanged<int> onTab;

  /// Reads the version from the installed package so the header can never
  /// drift from the build the user is actually running.
  Future<String> _version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Every colour here comes from the AppColors statics, which are swapped
    // in before this subtree builds. Watching AppState is what marks the
    // header dirty on a theme change. Without it the only inherited lookup
    // lives in the children, so the header itself stays put until a tab
    // switch rebuilds it.
    context.watch<AppState>();

    return ColoredBox(
      color: context.appBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(
                      Icons.menu_rounded,
                      color: context.appOnSurfaceVariant,
                    ),
                    tooltip: 'Menu',
                  ),
                  const Spacer(),
                  const MiraiWordmark(size: 20),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => onTab(_AppShellState._settingsIndex),
                    child: FutureBuilder<String>(
                      future: _version(),
                      builder: (context, snap) {
                        final version = snap.data ?? '';
                        if (version.isEmpty) return const SizedBox.shrink();
                        return Text(
                          'v$version',
                          style: context.appTextTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _Drawer extends StatelessWidget {
  const _Drawer({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<UpdateNotifier>();
    final state = context.watch<AppState>();
    final updates = notifier.hasUpdateOn(
      state.updateChannel == UpdateChannel.beta,
    )
        ? notifier.latest
        : null;

    return Drawer(
      backgroundColor: context.appBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              child: MiraiWordmark(size: 20),
            ),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 8),
            for (var i = 0; i < _AppShellState._tabs.length; i++)
              _DrawerItem(
                label: _AppShellState._tabs[i].label,
                icon: _AppShellState._tabs[i].icon,
                selected: selected == i,
                onTap: () => onSelect(i),
              ),
            if (updates != null)
              _DrawerItem(
                label: 'Update to v${updates.version}',
                icon: Icons.arrow_upward_rounded,
                selected: false,
                onTap: () => Navigator.of(context)
                    .push(UpdateScreen.route(notifier.checker)),
              ),
            const Spacer(),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 8),
            _DrawerItem(
              label: 'About',
              icon: Icons.info_rounded,
              selected: false,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        selected ? context.appAccent : context.appOnSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? activeColor : null),
              const SizedBox(width: 16),
              Text(
                label.toUpperCase(),
                style: context.appTextTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: activeColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}