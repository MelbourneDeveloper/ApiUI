import 'package:flutter/material.dart';
import 'package:flutter_app/src/theme/color_generator.dart';

/// Chat-specific semantic colors stored as a theme extension.
@immutable
final class ChatColors extends ThemeExtension<ChatColors> {
  const ChatColors._({
    required this.userBubble,
    required this.userBubbleText,
    required this.assistantBubble,
    required this.assistantBubbleText,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputText,
    required this.hintText,
    required this.sendButton,
    required this.sendButtonIcon,
    required this.timestamp,
    required this.linkColor,
    required this.codeBackground,
    required this.authCardBackground,
    required this.chartBorder,
    required this.chartPrimary,
    required this.chartSecondary,
    required this.chartTertiary,
    required this.chartAxisLabel,
    required this.accent,
  });

  /// Creates chat colors from a generated palette.
  factory ChatColors.fromPalette(ColorPalette palette) => ChatColors._(
    userBubble: palette.userBubble,
    userBubbleText: palette.onSurface,
    assistantBubble: palette.assistantBubble,
    assistantBubbleText: palette.onSurface,
    inputBackground: palette.inputBackground,
    inputBorder: palette.divider,
    inputText: palette.onSurface,
    hintText: palette.onSurface.withValues(alpha: 0.5),
    sendButton: palette.primary,
    sendButtonIcon: palette.onPrimary,
    timestamp: palette.onSurface.withValues(alpha: 0.5),
    linkColor: palette.primary,
    codeBackground: palette.surface,
    authCardBackground: palette.tertiary.withValues(alpha: 0.15),
    chartBorder: palette.divider,
    chartPrimary: palette.chartPrimary,
    chartSecondary: palette.chartSecondary,
    chartTertiary: palette.chartTertiary,
    chartAxisLabel: palette.chartAxisLabel,
    accent: palette.accent,
  );

  final Color userBubble;
  final Color userBubbleText;
  final Color assistantBubble;
  final Color assistantBubbleText;
  final Color inputBackground;
  final Color inputBorder;
  final Color inputText;
  final Color hintText;
  final Color sendButton;
  final Color sendButtonIcon;
  final Color timestamp;
  final Color linkColor;
  final Color codeBackground;
  final Color authCardBackground;
  final Color chartBorder;
  final Color chartPrimary;
  final Color chartSecondary;
  final Color chartTertiary;
  final Color chartAxisLabel;
  final Color accent;

  // Required by ThemeExtension but never called - no theme animations
  @override
  ThemeExtension<ChatColors> copyWith() => this;

  @override
  ThemeExtension<ChatColors> lerp(ChatColors? other, double t) => other ?? this;
}
