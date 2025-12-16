import 'package:flutter/material.dart';

/// Creates text theme using system fonts with MD3 sizes.
TextTheme createTextTheme({required bool isDark}) {
  final baseColor = isDark ? Colors.white : const Color(0xFF1A1C20);

  return TextTheme(
    displayLarge: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
    displayMedium: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
    displaySmall: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
    headlineLarge: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: baseColor),
    titleSmall: TextStyle(color: baseColor),
    bodyLarge: TextStyle(color: baseColor),
    bodyMedium: TextStyle(color: baseColor),
    bodySmall: TextStyle(color: baseColor),
    labelLarge: TextStyle(color: baseColor),
    labelMedium: TextStyle(color: baseColor),
    labelSmall: TextStyle(color: baseColor),
  );
}
