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
  late final List<Animation<double>> _letterFades;
  late final List<Animation<Offset>> _letterSlides;
  late final Animation<double> _shimmer;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    const int letterCount = 5; // M I R A I
    _letterFades = List.generate(letterCount, (i) {
      final start = 0.05 + i * 0.1; // 50ms stagger
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
    _letterSlides = List.generate(letterCount, (i) {
      final start = 0.05 + i * 0.1;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    // Shimmer sweep starts after letters settle
    _shimmer = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.9, curve: Curves.easeInOut),
    );

    // Tagline fades in last
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'I', 'R', 'A', 'I'];

    return Scaffold(
      backgroundColor: context.appBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated wordmark with letter stagger + shimmer
            Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Accent bar - animate with first letter
                    ScaleTransition(
                      scale: _letterFades[0],
                      child: Container(
                        width: 46 * 0.18,
                        height: 46 * 0.9,
                        color: context.appAccent,
                      ),
                    ),
                    SizedBox(width: 46 * 0.12),
                    // Individual animated letters
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(letters.length, (i) {
                        return SlideTransition(
                          position: _letterSlides[i],
                          child: FadeTransition(
                            opacity: _letterFades[i],
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    context.appOnSurface,
                                    context.appAccent,
                                  ],
                                ).createShader(bounds);
                              },
                              child: Text(
                                letters[i],
                                style: context.appTextTheme.displayMedium
                                    ?.copyWith(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  letterSpacing: 0.02,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                // Shimmer sweep overlay
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (context, child) {
                    if (_shimmer.value == 0) return const SizedBox.shrink();
                    return IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                                -1.5 + 3 * _shimmer.value, 0),
                            end: Alignment(
                                -0.5 + 3 * _shimmer.value, 0),
                            colors: [
                              Colors.transparent,
                              context.appAccent.withOpacity(0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            // Tagline fade-in
            FadeTransition(
              opacity: _taglineFade,
              child: Text(
                'Your Anime streaming buddy',
                style: context.appTextTheme.labelSmall?.copyWith(
                  color: context.appOnSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}