import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mirai's palette is a "neon broadcast": cool ink, paper, hairline dividers
/// and one signal accent — volt lime. The display type is tight condensed
/// broadcast copy; body and UI run on a clean neutral sans. The whole system
/// is deliberately a different register from Kumi's warm, rounded look.
class AppColors {
  AppColors._();

  static const _lInk = Color(0xFFEDEFF4); // cool paper background
  static const _lSurface = Color(0xFFFFFFFF);
  static const _lOnSurface = Color(0xFF101218);
  static const _lOnSurfaceVar = Color(0xFF5E6478);
  static const _lOutline = Color(0xFFD8DCE6);
  static const _lSurfaceVar = Color(0xFFE4E7EF);
  static const _lError = Color(0xFFB3261E);

  static const _dInk = Color(0xFF05060A); // near-black with a blue undertone
  static const _dSurface = Color(0xFF0D0F16);
  static const _dOnSurface = Color(0xFFEDF0F8);
  static const _dOnSurfaceVar = Color(0xFF8E96AC);
  static const _dOutline = Color(0xFF222735);
  static const _dSurfaceVar = Color(0xFF161A24);
  static const _dError = Color(0xFFF2B8B5);

  static const _volt = Color(0xFFC6F84E); // signal accent
  static const _voltOn = Color(0xFF0A0B12); // foreground on volt
  static const _voltSoft = Color(0xFF222B18); // subtle volt tint for dark

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

  /// Foreground for anything sitting on top of [accentSoft].
  ///
  /// [onAccent] only pairs with the solid [accent]. Because [accentSoft]
  /// flips to a dark tint in dark mode, its readable partner has to flip too
  /// (near-black on volt when light, near-white on the dark tint when dark).
  static Color get onAccentSoft => _isDark ? _dOnSurface : _voltOn;

  static Color get cardBorder => _isDark ? _dOutline : _lOutline;
}

/// Sharp radius scale: crisp corners for cards, softer for fields and chips.
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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
  return _applyComponentThemes(
    base.copyWith(textTheme: buildAppTextTheme(base.textTheme)),
  );
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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
  return _applyComponentThemes(
    base.copyWith(textTheme: buildAppTextTheme(base.textTheme)),
  );
}

/// Global component styling so every screen shares the broadcast register:
/// flat app bars, volt-filled buttons, and hairline dividers.
ThemeData _applyComponentThemes(ThemeData theme) {
  return theme.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: AppColors.outline),
  );
}

TextTheme buildAppTextTheme(TextTheme base) {
  final display = GoogleFonts.barlowCondensedTextTheme(base);
  final body = GoogleFonts.interTextTheme(base);
  return display.copyWith(
    displayLarge: display.displayLarge?.copyWith(
      fontSize: 66,
      fontWeight: FontWeight.w800,
      height: 0.9,
      letterSpacing: -0.01,
    ),
    displayMedium: display.displayMedium?.copyWith(
      fontSize: 48,
      fontWeight: FontWeight.w800,
      height: 0.95,
      letterSpacing: -0.01,
    ),
    headlineMedium: display.headlineMedium?.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: -0.01,
    ),
    headlineSmall: display.headlineSmall?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.05,
    ),
    titleLarge: display.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: -0.005,
    ),
    titleMedium: display.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    bodyLarge: body.bodyLarge?.copyWith(fontSize: 15, height: 1.6),
    bodyMedium: body.bodyMedium?.copyWith(
      fontSize: 13,
      height: 1.55,
      color: AppColors.onSurfaceVariant,
    ),
    bodySmall: body.bodySmall?.copyWith(fontSize: 12, height: 1.4),
    titleSmall: body.titleSmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: body.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.2,
      color: AppColors.onSurfaceVariant,
    ),
    labelMedium: body.labelMedium?.copyWith(
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
  Color get appOnAccentSoft => AppColors.onAccentSoft;
  Color get appOutline => AppColors.outline;
  TextTheme get appTextTheme => Theme.of(this).textTheme;
}