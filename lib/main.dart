import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/mirai_wordmark.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MiraiApp());
}

class MiraiApp extends StatelessWidget {
  const MiraiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          final brightness = state.themeMode == ThemeMode.system
              ? WidgetsBinding.instance.platformDispatcher.platformBrightness
              : state.themeMode == ThemeMode.dark
                  ? Brightness.dark
                  : Brightness.light;
          AppColors.setThemeBrightness(brightness);
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            systemNavigationBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: brightness,
          ));

          return MaterialApp(
            title: 'Mirai',
            theme: buildAppTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: state.themeMode,
            debugShowCheckedModeBanner: false,
            home: const SplashGate(),
          );
        },
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      child: _showSplash
          ? const SplashScreen(key: ValueKey('splash'))
          : const AppShell(key: ValueKey('shell')),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fade,
              child: const MiraiWordmark(size: 46),
            ),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: _fade,
              child: Text(
                'NIGHT BROADCAST',
                style: context.appTextTheme.labelSmall?.copyWith(
                  color: context.appOnSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}