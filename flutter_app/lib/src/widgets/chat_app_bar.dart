import 'package:flutter/material.dart';
import 'package:flutter_app/src/theme/chat_colors.dart';
import 'package:flutter_app/src/theme/responsive.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';

/// Builds a minimal custom app bar with accent indicator.
PreferredSizeWidget buildChatAppBar({
  required String title,
  required Breakpoint breakpoint,
  required BuildContext context,
}) {
  final colors = Theme.of(context).extension<ChatColors>()!;
  final theme = Theme.of(context);
  final height = responsiveAppBarHeight(breakpoint);

  return PreferredSize(
    preferredSize: Size.fromHeight(height),
    child: Container(
      height: height + MediaQuery.paddingOf(context).top,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: colors.inputBorder)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsivePadding(breakpoint),
        ),
        child: Row(
          children: [
            Container(
              width: spacingSm,
              height: spacingSm,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: spacingMd),
            Text(
              title,
              style: TextStyle(
                fontSize: theme.textTheme.titleLarge?.fontSize,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
