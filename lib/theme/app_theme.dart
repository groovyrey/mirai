import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mirai's palette is a "night broadcast" editorial: ink, paper, hairline
/// dividers and one signal accent — volt lime. The display type runs wide and
/// light on it.
class AppColors {
  AppColors._();

  static const _lInk = Color(0xFFF4F5F9); // paper background (light mode)
  static const _lSurface = Color(0xFFFFFFFF);
  static const _lOnSurface = Color(0xFF17181D);
  static const _lOnSurfaceVar = Color(0xFF5C6072);
  static const _lOutline = Color(0xFFDCDEE6);
  static const _lSurfaceVar = Color(0xFFECEDF2);
  static const _lError = Color(0xFFB3261E);

  static const _dInk = Color(0xFF0A0B12); // near-black ink
  static const _dSurface = Color(0xFF12141E);
  static const _dOnSurface = Color(0xFFF2F3F7);
  static const _dOnSurfaceVar = Color(0xFF9096A9);
  static const _dOutline = Color(0xFF23262F);
  static const _dSurfaceVar = Color(0xFF1B1D28);
  static const _dError = Color(0xFFF2B8B5);

  static const _volt = Color(0xFFC6F84E); // signal accent
  static const _voltOn = Color(0xFF0A0B12); // foreground on volt
  static const _voltSoft = Color(0xFF232B1C); // subtle volt tint for dark

  static bool _isDark = false;

  static void setThemeBrightness(Brightness b) =>
      _isDark = b == Brightness.dark;

  static Color get background => _isDark ? _dInk : _lInk;
  static Color get surface => _isDark ? _dSurface : _lSurface;
  static Color get onSurface => _isDark ? _dOnSurface : _lOnSurface;
  static Color get onSurfaceVariant => _isDark ? _dOnSurfaceVar : _lOnSurfaceVar;
  static Color get outline => _isDark ? _dOutline : _lOutline;
  static Color get surfaceVariant => _isDark ? _dSurfaceVar : _lSurfaceVar;
  static Color get error => _isDark ? _dError : _lError;
  static Color get accent => _volt;
  static Color get accentSoft => _isDark ? _voltSoft : _volt;
  static Color get onAccent => _voltOn;
}

/// Brash radius scale: crisp corners for cards, softer for fields and chips.
class AppRadius {
  AppRadius._();

  static const double card = 6;
  static const double control = 10;
  static const double field = 8;
  static const double chip = 999;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: AppColors.accentSoft,
      onSecondaryContainer: AppColors.onAccent,
      surface: AppColors._lSurface,
      surfaceContainerHighest: AppColors._lSurfaceVar,
      error: AppColors._lError,
      onSurface: AppColors._lOnSurface,
      onSurfaceVariant: AppColors._lOnSurfaceVar,
      outline: AppColors._lOutline,
      onError: AppColors._lSurface,
    ),
    scaffoldBackgroundColor: AppColors._lInk,
    dividerColor: AppColors._lOutline,
  );
  return base.copyWith(textTheme: buildAppTextTheme(base.textTheme));
}

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: AppColors.accentSoft,
      onSecondaryContainer: AppColors.onAccent,
      surface: AppColors._dSurface,
      surfaceContainerHighest: AppColors._dSurfaceVar,
      error: AppColors._dError,
      onSurface: AppColors._dOnSurface,
      onSurfaceVariant: AppColors._dOnSurfaceVar,
      outline: AppColors._dOutline,
      onError: AppColors._dSurface,
    ),
    scaffoldBackgroundColor: AppColors._dInk,
    dividerColor: AppColors._dOutline,
  );
  return base.copyWith(textTheme: buildAppTextTheme(base.textTheme));
}

TextTheme buildAppTextTheme(TextTheme base) {
  final display = GoogleFonts.syneTextTheme(base);
  return display.copyWith(
    displayLarge: display.displayLarge?.copyWith(
      fontSize: 64,
      fontWeight: FontWeight.w700,
      height: 0.95,
      letterSpacing: -0.03,
    ),
    displayMedium: display.displayMedium?.copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: -0.02,
    ),
    headlineMedium: display.headlineMedium?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: -0.02,
    ),
    headlineSmall: display.headlineSmall?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.01,
    ),
    titleLarge: display.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.01,
    ),
    titleMedium: display.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, height: 1.6),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 13,
      height: 1.55,
      color: AppColors.onSurfaceVariant,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.2,
      color: AppColors.onSurfaceVariant,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
  );
}

extension AppThemeX on BuildContext {
  Color get appSurface => AppColors.surface;
  Color get appBackground => AppColors.background;
  Color get appOnSurface => AppColors.onSurface;
  Color get appOnSurfaceVariant => AppColors.onSurfaceVariant;
  Color get appSurfaceVariant => AppColors.surfaceVariant;
  Color get appAccent => AppColors.accent;
  Color get appAccentSoft => AppColors.accentSoft;
  Color get appOnAccent => AppColors.onAccent;
  Color get appOutline => AppColors.outline;
  TextTheme get appTextTheme => Theme.of(this).textTheme;
}