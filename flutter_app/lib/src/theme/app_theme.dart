import 'package:flutter/material.dart';
import 'package:flutter_app/src/theme/chat_colors.dart';
import 'package:flutter_app/src/theme/color_generator.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';
import 'package:flutter_app/src/theme/typography.dart';

/// Builds complete ThemeData from a color palette.
ThemeData buildTheme(ColorPalette palette, {required bool isDark}) {
  final textTheme = createTextTheme(isDark: isDark);
  final chatColors = ChatColors.fromPalette(palette);

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      onSecondary: palette.onSecondary,
      tertiary: palette.tertiary,
      surface: palette.surface,
      onSurface: palette.onSurface,
      error: palette.error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: palette.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: palette.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusPill),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusPill),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusPill),
        borderSide: BorderSide(color: palette.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingXl,
        vertical: spacingMd,
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: palette.onSurface.withValues(alpha: 0.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXl,
          vertical: spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXl,
          vertical: spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        side: BorderSide(color: palette.primary),
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
    extensions: [chatColors],
  );
}

/// Creates light theme from seed hue.
ThemeData buildLightTheme(double seedHue) =>
    buildTheme(generatePalette(seedHue, isDark: false), isDark: false);

/// Creates dark theme from seed hue.
ThemeData buildDarkTheme(double seedHue) =>
    buildTheme(generatePalette(seedHue, isDark: true), isDark: true);
