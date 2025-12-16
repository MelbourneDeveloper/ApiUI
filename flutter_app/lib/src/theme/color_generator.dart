import 'package:flutter/material.dart';

/// Complete color palette generated from a seed hue.
typedef ColorPalette = ({
  Color primary,
  Color secondary,
  Color tertiary,
  Color accent,
  Color surface,
  Color background,
  Color onPrimary,
  Color onSecondary,
  Color onSurface,
  Color onBackground,
  Color userBubble,
  Color assistantBubble,
  Color inputBackground,
  Color divider,
  Color error,
  Color success,
  Color chartPrimary,
  Color chartSecondary,
  Color chartTertiary,
  Color chartAxisLabel,
});

// Purple hue range to exclude (270-310 degrees).
const double _purpleStart = 270;
const double _purpleEnd = 310;

/// App seed hue - golden yellow-green (generated once, do not change).
const double appSeedHue = 66;

/// Shifts hue away from purple range (270-310).
double _avoidPurple(double hue) => switch (hue) {
  >= _purpleStart && < 290 => _purpleStart - 1,
  >= 290 && <= _purpleEnd => _purpleEnd + 1,
  _ => hue,
};

/// Normalizes hue to 0-360 range.
double _normalizeHue(double hue) => hue % 360;

/// Creates HSL color with normalized hue.
Color _hsl(double hue, double saturation, double lightness) =>
    HSLColor.fromAHSL(
      1,
      _avoidPurple(_normalizeHue(hue)),
      saturation,
      lightness,
    ).toColor();

/// Generates complete color palette from seed hue.
ColorPalette generatePalette(double seedHue, {required bool isDark}) =>
    isDark ? _generateDarkPalette(seedHue) : _generateLightPalette(seedHue);

ColorPalette _generateLightPalette(double seedHue) {
  final primary = _hsl(seedHue, 0.65, 0.45);
  final secondary = _hsl(seedHue + 150, 0.55, 0.50);
  final tertiary = _hsl(seedHue + 210, 0.55, 0.50);
  final accent = _hsl(seedHue + 30, 0.75, 0.50);

  return (
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    accent: accent,
    surface: _hsl(seedHue, 0.05, 0.98),
    background: _hsl(seedHue, 0.08, 0.96),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: _hsl(seedHue, 0.10, 0.15),
    onBackground: _hsl(seedHue, 0.10, 0.15),
    userBubble: _hsl(seedHue, 0.60, 0.92),
    assistantBubble: _hsl(seedHue, 0.05, 0.94),
    inputBackground: _hsl(seedHue, 0.05, 0.99),
    divider: _hsl(seedHue, 0.08, 0.88),
    error: _hsl(0, 0.70, 0.50),
    success: _hsl(140, 0.65, 0.45),
    chartPrimary: primary,
    chartSecondary: secondary,
    chartTertiary: tertiary,
    chartAxisLabel: _hsl(seedHue, 0.10, 0.40),
  );
}

ColorPalette _generateDarkPalette(double seedHue) {
  // Beautiful modern dark theme - NO PURPLE, only greens/teals/blues
  final primary = _hsl(seedHue, 0.75, 0.55); // Yellow-green from seed
  final secondary = _hsl(190, 0.65, 0.50); // Cyan/teal
  final tertiary = _hsl(160, 0.60, 0.45); // Green-teal
  final accent = _hsl(seedHue, 0.85, 0.60);

  return (
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    accent: accent,
    surface: _hsl(200, 0.15, 0.14), // Dark blue-gray
    background: _hsl(200, 0.20, 0.08), // Deep dark
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: _hsl(seedHue, 0.08, 0.94),
    onBackground: _hsl(seedHue, 0.08, 0.94),
    userBubble: _hsl(seedHue, 0.60, 0.38), // Vibrant yellow-green
    assistantBubble: _hsl(200, 0.12, 0.18), // Subtle dark gray-blue
    inputBackground: _hsl(200, 0.15, 0.14),
    divider: _hsl(200, 0.12, 0.24),
    error: _hsl(0, 0.70, 0.55),
    success: _hsl(140, 0.65, 0.50),
    chartPrimary: primary,
    chartSecondary: secondary,
    chartTertiary: tertiary,
    chartAxisLabel: _hsl(seedHue, 0.12, 0.78),
  );
}
