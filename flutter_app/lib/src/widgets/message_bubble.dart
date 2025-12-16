import 'package:flutter/material.dart';
import 'package:flutter_app/src/theme/chat_colors.dart';
import 'package:flutter_app/src/theme/responsive.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Builds a styled message bubble with role-aware decoration.
Widget buildMessageBubble({
  required String content,
  required bool isUser,
  required Breakpoint breakpoint,
  required BuildContext context,
  void Function(String?, String?, String)? onTapLink,
}) {
  final colors = Theme.of(context).extension<ChatColors>()!;
  final maxWidthPercent = responsiveBubbleMaxWidth(breakpoint);
  final screenWidth = MediaQuery.sizeOf(context).width;
  final bubbleColor = isUser ? colors.userBubble : colors.assistantBubble;

  return Container(
    constraints: BoxConstraints(maxWidth: screenWidth * maxWidthPercent),
    padding: EdgeInsets.symmetric(
      horizontal: responsive(breakpoint, phone: spacingLg, desktop: spacingXl),
      vertical: responsive(breakpoint, phone: spacingMd, desktop: spacingLg),
    ),
    decoration: BoxDecoration(
      gradient: isUser
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bubbleColor,
                bubbleColor.withValues(alpha: 0.85),
              ],
            )
          : null,
      color: isUser ? null : bubbleColor,
      borderRadius: _bubbleBorderRadius(isUser),
      boxShadow: [
        BoxShadow(
          color: bubbleColor.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: MarkdownBody(
      data: content,
      styleSheet: _markdownStyle(context, isUser, colors),
      onTapLink: (text, href, title) => onTapLink?.call(text, href, title),
    ),
  );
}

BorderRadius _bubbleBorderRadius(bool isUser) => BorderRadius.only(
  topLeft: const Radius.circular(radiusBubble),
  topRight: const Radius.circular(radiusBubble),
  bottomLeft: Radius.circular(isUser ? radiusBubble : radiusBubbleTail),
  bottomRight: Radius.circular(isUser ? radiusBubbleTail : radiusBubble),
);

MarkdownStyleSheet _markdownStyle(
  BuildContext context,
  bool isUser,
  ChatColors colors,
) {
  final textColor = isUser ? colors.userBubbleText : colors.assistantBubbleText;
  final baseStyle = Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: textColor);

  return MarkdownStyleSheet(
    p: baseStyle,
    a: baseStyle?.copyWith(
      color: colors.linkColor,
      decoration: TextDecoration.underline,
    ),
    code: baseStyle?.copyWith(
      backgroundColor: colors.codeBackground,
      fontFamily: 'monospace',
    ),
    codeblockDecoration: BoxDecoration(
      color: colors.codeBackground,
      borderRadius: BorderRadius.circular(radiusSm),
    ),
  );
}
