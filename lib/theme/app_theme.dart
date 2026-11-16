import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mirai follows the workload-wireframe system: paper, white panels, hairline
/// rules, one blue signal accent, and flat surfaces. The streaming layer keeps
/// its posters, rails, and dark player, so the app still reads as a cinema
/// product rather than a dashboard.
class AppColors {
  AppColors._();

  static const _lInk = Color(0xFFF1F5F9);
  static const _lSurface = Color(0xFFFFFFFF);
  static const _lSurfaceAlt = Color(0xFFF8FAFC);
  static const _lOnSurface = Color(0xFF101828);
  static const _lOnSurfaceVar = Color(0xFF475467);
  static const _lMuted = Color(0xFF64748B);
  static const _lOutline = Color(0xFFE2E8F0);
  static const _lOutlineStrong = Color(0xFFCBD5E1);
  static const _lSurfaceVar = Color(0xFFE2E8F0);
  static const _lError = Color(0xFFDC2626);
  static const _lSuccess = Color(0xFF15803D);
  static const _lWarning = Color(0xFFB45309);
  static const _lAccent = Color(0xFF2563EB);
  static const _lAccentDeep = Color(0xFF1D4ED8);
  static const _lAccentSoft = Color(0xFFDBEAFE);
  static const _lOnAccent = Color(0xFFFFFFFF);
  static const _lOnAccentSoft = Color(0xFF1E40AF);

  static const _dInk = Color(0xFF0B0F17);
  static const _dSurface = Color(0xFF111827);
  static const _dSurfaceAlt = Color(0xFF172033);
  static const _dOnSurface = Color(0xFFF8FAFC);
  static const _dOnSurfaceVar = Color(0xFF94A3B8);
  static const _dMuted = Color(0xFF64748B);
  static const _dOutline = Color(0xFF263244);
  static const _dOutlineStrong = Color(0xFF334155);
  static const _dSurfaceVar = Color(0xFF1E293B);
  static const _dError = Color(0xFFF87171);
  static const _dSuccess = Color(0xFF4ADE80);
  static const _dWarning = Color(0xFFFBBF24);
  static const _dAccent = Color(0xFF60A5FA);
  static const _dAccentDeep = Color(0xFF93C5FD);
  static const _dAccentSoft = Color(0xFF172554);
  static const _dOnAccent = Color(0xFF08111F);
  static const _dOnAccentSoft = Color(0xFFDBEAFE);

  static bool _isDark = false;

  static void setThemeBrightness(Brightness b) =>
      _isDark = b == Brightness.dark;

  static Color get background => _isDark ? _dInk : _lInk;
  static Color get surface => _isDark ? _dSurface : _lSurface;
  static Color get surfaceAlt => _isDark ? _dSurfaceAlt : _lSurfaceAlt;
  static Color get onSurface => _isDark ? _dOnSurface : _lOnSurface;
  static Color get onSurfaceVariant => _isDark ? _dOnSurfaceVar : _lOnSurfaceVar;
  static Color get muted => _isDark ? _dMuted : _lMuted;
  static Color get outline => _isDark ? _dOutline : _lOutline;
  static Color get outlineStrong => _isDark ? _dOutlineStrong : _lOutlineStrong;
  static Color get surfaceVariant => _isDark ? _dSurfaceVar : _lSurfaceVar;
  static Color get error => _isDark ? _dError : _lError;
  static Color get success => _isDark ? _dSuccess : _lSuccess;
  static Color get warning => _isDark ? _dWarning : _lWarning;
  static Color get accent => _isDark ? _dAccent : _lAccent;
  static Color get accentDeep => _isDark ? _dAccentDeep : _lAccentDeep;
  static Color get accentSoft => _isDark ? _dAccentSoft : _lAccentSoft;
  static Color get onAccent => _isDark ? _dOnAccent : _lOnAccent;
  static Color get onAccentSoft => _isDark ? _dOnAccentSoft : _lOnAccentSoft;

  /// Foreground for anything sitting on top of [accentSoft].
  static Color get onAccentSoftStrong => _isDark ? _dOnSurface : _lOnAccentSoft;

  static Color get cardBorder => outline;

  static const focusLight = Color(0x262563EB);
  static const focusDark = Color(0x3860A5FA);
}

/// The wireframe radius scale: crisp 8px panels, 6px controls, 6px chips.
class AppRadius {
  AppRadius._();

  static const double card = 8;
  static const double control = 8;
  static const double field = 6;
  static const double chip = 6;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.light(
    primary: AppColors._lAccent,
    onPrimary: AppColors._lOnAccent,
    primaryContainer: AppColors._lAccentSoft,
    onPrimaryContainer: AppColors._lOnAccentSoft,
    secondary: AppColors._lAccentDeep,
    onSecondary: AppColors._lOnAccent,
    secondaryContainer: AppColors._lAccentSoft,
    onSecondaryContainer: AppColors._lOnAccentSoft,
    surface: AppColors._lSurface,
    surfaceContainerHighest: AppColors._lSurfaceVar,
    error: AppColors._lError,
    onSurface: AppColors._lOnSurface,
    onSurfaceVariant: AppColors._lOnSurfaceVar,
    outline: AppColors._lOutline,
    outlineVariant: AppColors._lOutlineStrong,
    onError: AppColors._lSurface,
  ).copyWith(surfaceTint: Colors.transparent);

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors._lInk,
    dividerColor: AppColors._lOutline,
    iconTheme: IconThemeData(color: AppColors._lOnSurfaceVar),
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
  final scheme = ColorScheme.dark(
    primary: AppColors._dAccent,
    onPrimary: AppColors._dOnAccent,
    primaryContainer: AppColors._dAccentSoft,
    onPrimaryContainer: AppColors._dOnAccentSoft,
    secondary: AppColors._dAccentDeep,
    onSecondary: AppColors._dOnAccent,
    secondaryContainer: AppColors._dAccentSoft,
    onSecondaryContainer: AppColors._dOnAccentSoft,
    surface: AppColors._dSurface,
    surfaceContainerHighest: AppColors._dSurfaceVar,
    error: AppColors._dError,
    onSurface: AppColors._dOnSurface,
    onSurfaceVariant: AppColors._dOnSurfaceVar,
    outline: AppColors._dOutline,
    outlineVariant: AppColors._dOutlineStrong,
    onError: AppColors._dSurface,
  ).copyWith(surfaceTint: Colors.transparent);

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors._dInk,
    dividerColor: AppColors._dOutline,
    iconTheme: IconThemeData(color: AppColors._dOnSurfaceVar),
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
    base.copyWith(textTheme: buildAppTextTheme(base.textTheme, dark: true)),
  );
}

/// Global component styling so every screen shares the wireframe register:
/// flat app bars, hairline outlines, plain fields, and blue signal actions.
ThemeData _applyComponentThemes(ThemeData theme) {
  final c = theme.colorScheme;
  final radius = BorderRadius.circular(AppRadius.control);

  return theme.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: c.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: c.onSurfaceVariant),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: c.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: c.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: theme.textTheme.labelLarge?.copyWith(
        color: c.onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
      prefixIconColor: c.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: c.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: c.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: c.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: c.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: c.error, width: 1.4),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      modalBackgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card + 4),
        ),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      scrimColor: Colors.black.withValues(alpha: 0.32),
    ),
    listTileTheme: ListTileThemeData(
      textColor: c.onSurface,
      iconColor: c.onSurfaceVariant,
      subtitleColor: c.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceContainerHighest,
      side: BorderSide(color: c.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      labelStyle: TextStyle(
        color: c.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: c.outline,
      thickness: 1,
      space: 1,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.primary,
      inactiveTrackColor: c.outline,
      thumbColor: c.primary,
      overlayColor: c.primary.withValues(alpha: 0.12),
      trackHeight: 3,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.outline,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.onSurface,
      contentTextStyle: TextStyle(color: c.surface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}

TextTheme buildAppTextTheme(TextTheme base, {bool dark = false}) {
  final onSurface = dark ? AppColors._dOnSurface : AppColors._lOnSurface;
  final onSurfaceVar =
      dark ? AppColors._dOnSurfaceVar : AppColors._lOnSurfaceVar;
  final muted = dark ? AppColors._dMuted : AppColors._lMuted;
  final display = GoogleFonts.outfitTextTheme(base);
  final body = GoogleFonts.plusJakartaSansTextTheme(base);
  return display.copyWith(
    displayLarge: display.displayLarge?.copyWith(
      fontSize: 52,
      fontWeight: FontWeight.w700,
      height: 0.98,
      letterSpacing: -1.2,
      color: onSurface,
    ),
    displayMedium: display.displayMedium?.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: -0.8,
      color: onSurface,
    ),
    headlineMedium: display.headlineMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: -0.4,
      color: onSurface,
    ),
    headlineSmall: display.headlineSmall?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.1,
      color: onSurface,
    ),
    titleLarge: display.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.2,
      color: onSurface,
    ),
    titleMedium: display.titleMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: onSurface,
    ),
    bodyLarge: body.bodyLarge?.copyWith(
      fontSize: 14,
      height: 1.6,
      color: onSurface,
    ),
    bodyMedium: body.bodyMedium?.copyWith(
      fontSize: 13,
      height: 1.55,
      color: onSurfaceVar,
    ),
    bodySmall: body.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.4,
      color: onSurfaceVar,
    ),
    titleSmall: body.titleSmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    labelLarge: body.labelLarge?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: onSurface,
    ),
    labelMedium: body.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: onSurfaceVar,
    ),
    labelSmall: body.labelSmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: muted,
    ),
  );
}

extension AppThemeX on BuildContext {
  Color get appSurface => AppColors.surface;
  Color get appSurfaceAlt => AppColors.surfaceAlt;
  Color get appBackground => AppColors.background;
  Color get appOnSurface => AppColors.onSurface;
  Color get appOnSurfaceVariant => AppColors.onSurfaceVariant;
  Color get appMuted => AppColors.muted;
  Color get appSurfaceVariant => AppColors.surfaceVariant;
  Color get appAccent => AppColors.accent;
  Color get appAccentDeep => AppColors.accentDeep;
  Color get appAccentSoft => AppColors.accentSoft;
  Color get appOnAccent => AppColors.onAccent;
  Color get appOnAccentSoft => AppColors.onAccentSoft;
  Color get appOutline => AppColors.outline;
  Color get appOutlineStrong => AppColors.outlineStrong;
  Color get appSuccess => AppColors.success;
  Color get appDanger => AppColors.error;
  Color get appWarning => AppColors.warning;
  TextTheme get appTextTheme => Theme.of(this).textTheme;
}
