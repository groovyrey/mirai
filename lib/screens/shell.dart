import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/saved.dart';
import '../services/watch_history.dart';
import '../theme/app_theme.dart';
import '../widgets/mirai_wordmark.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'saved_screen.dart';
import 'search_screen.dart';
import 'trending_screen.dart';

/// Mirai's shell: a wordmark header with an editorial section tab strip.
/// Not Kumi's floating pill — the tabs sit against the header hairline so the
/// browsing surface stays clean.
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
    (icon: Icons.more_horiz_rounded, label: 'More'),
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
      const MoreScreen(key: ValueKey('more')),
    ];

    return Scaffold(
      body: Column(
        children: [
          _Header(
            onTab: onTab,
            selected: index,
          ),
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
  const _Header({required this.selected, required this.onTab});

  final int selected;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
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
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    for (var i = 0; i < _AppShellState._tabs.length; i++)
                      Expanded(
                        child: _TabButton(
                          label: _AppShellState._tabs[i].label,
                          icon: _AppShellState._tabs[i].icon,
                          selected: selected == i,
                          onTap: () => onTab(i),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
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
    final activeColor = selected ? context.appAccent : context.appOnSurfaceVariant;
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: selected ? activeColor : null),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: context.appTextTheme.labelSmall?.copyWith(
              fontSize: 9,
              letterSpacing: 1.2,
              color: activeColor,
            ),
          ),
        ],
      ),
    );
  }
}