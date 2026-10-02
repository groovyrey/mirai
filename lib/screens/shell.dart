import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/saved.dart';
import '../services/watch_history.dart';
import '../theme/app_theme.dart';
import '../widgets/mirai_wordmark.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'trending_screen.dart';

/// Mirai's shell: a wordmark header with a drawer navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.play_arrow_rounded, label: 'Home'),
    (icon: Icons.local_fire_department_rounded, label: 'Trending'),
    (icon: Icons.bookmark_rounded, label: 'Saved'),
    (icon: Icons.search_rounded, label: 'Find'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: Saved.instance,
      child: ChangeNotifierProvider.value(
        value: WatchHistory.instance,
        child: _ShellScaffold(index: _index, onTab: _select),
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
      const SavedScreen(key: ValueKey('saved')),
      const SearchScreen(key: ValueKey('search')),
      const SettingsScreen(key: ValueKey('settings')),
    ];

    return Scaffold(
      drawer: _Drawer(selected: index, onSelect: onTab),
      body: Column(
        children: [
          _Header(onTab: onTab),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              child: sections[index],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
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
                    onTap: () => onTab(4),
                    child: Text(
                      'v1.0.0',
                      style: context.appTextTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
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