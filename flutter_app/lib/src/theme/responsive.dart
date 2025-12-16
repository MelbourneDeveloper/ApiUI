import 'package:flutter_app/src/theme/theme_constants.dart';

/// Device size breakpoints.
enum Breakpoint { phone, tablet, desktop }

// Breakpoint thresholds.
const double _phoneMax = 600;
const double _tabletMax = 1200;

/// Determines breakpoint from screen width.
Breakpoint breakpointFromWidth(double width) => switch (width) {
  < _phoneMax => Breakpoint.phone,
  < _tabletMax => Breakpoint.tablet,
  _ => Breakpoint.desktop,
};

/// Selects value based on current breakpoint.
T responsive<T>(
  Breakpoint breakpoint, {
  required T phone,
  T? tablet,
  T? desktop,
}) => switch (breakpoint) {
  Breakpoint.phone => phone,
  Breakpoint.tablet => tablet ?? phone,
  Breakpoint.desktop => desktop ?? tablet ?? phone,
};

/// Gets horizontal padding for current breakpoint.
double responsivePadding(Breakpoint breakpoint) => responsive(
  breakpoint,
  phone: spacingMd,
  tablet: spacingXl,
  desktop: spacingXxl,
);

/// Gets max content width for current breakpoint (null = fill available).
double? responsiveMaxWidth(Breakpoint breakpoint) => null;

/// Gets bubble max width percentage for current breakpoint.
double responsiveBubbleMaxWidth(Breakpoint breakpoint) => responsive(
  breakpoint,
  phone: bubbleMaxWidthPhone,
  tablet: bubbleMaxWidthTablet,
  desktop: bubbleMaxWidthDesktop,
);

/// Gets app bar height for current breakpoint.
double responsiveAppBarHeight(Breakpoint breakpoint) => responsive(
  breakpoint,
  phone: appBarHeightPhone,
  tablet: appBarHeightTablet,
  desktop: appBarHeightDesktop,
);
