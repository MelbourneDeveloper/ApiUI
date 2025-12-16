import 'package:flutter/material.dart';

// Spacing scale (multiples of 4).
const double spacingXs = 4;
const double spacingSm = 8;
const double spacingMd = 12;
const double spacingLg = 16;
const double spacingXl = 24;
const double spacingXxl = 32;

// Border radius presets.
const double radiusSm = 8;
const double radiusMd = 12;
const double radiusLg = 16;
const double radiusXl = 20;
const double radiusPill = 28;
const double radiusBubble = 20;
const double radiusBubbleTail = 4;

// Animation durations.
const Duration durationFast = Duration(milliseconds: 150);
const Duration durationMedium = Duration(milliseconds: 250);
const Duration durationSlow = Duration(milliseconds: 400);
const Duration durationScroll = Duration(milliseconds: 300);

// Icon sizes.
const double iconSizeSm = 16;
const double iconSizeMd = 20;
const double iconSizeLg = 24;
const double iconSizeXl = 32;

// App bar heights by breakpoint.
const double appBarHeightPhone = 56;
const double appBarHeightTablet = 64;
const double appBarHeightDesktop = 72;

// Message bubble max-width percentages by breakpoint.
const double bubbleMaxWidthPhone = 0.92;
const double bubbleMaxWidthTablet = 0.90;
const double bubbleMaxWidthDesktop = 0.88;

/// Creates subtle shadow for elevated elements.
List<BoxShadow> shadowSubtle(Color color) => [
  BoxShadow(
    color: color.withValues(alpha: 0.08),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

/// Creates elevated shadow for floating elements.
List<BoxShadow> shadowElevated(Color color) => [
  BoxShadow(
    color: color.withValues(alpha: 0.12),
    blurRadius: 20,
    offset: const Offset(0, 4),
  ),
];
