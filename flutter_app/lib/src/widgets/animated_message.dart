import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/theme/chat_colors.dart';
import 'package:flutter_app/src/theme/responsive.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';

/// Animated message row with avatar and slide-in animation.
class AnimatedMessageRow extends StatefulWidget {
  /// Creates an animated message row.
  const AnimatedMessageRow({
    required this.isUser,
    required this.breakpoint,
    required this.child,
    super.key,
  });

  /// Whether this is a user message.
  final bool isUser;

  /// Current breakpoint for responsive layout.
  final Breakpoint breakpoint;

  /// The message content widget.
  final Widget child;

  @override
  State<AnimatedMessageRow> createState() => _AnimatedMessageRowState();
}

class _AnimatedMessageRowState extends State<AnimatedMessageRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ChatColors>()!;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: spacingSm,
            horizontal: responsivePadding(widget.breakpoint),
          ),
          child: Row(
            mainAxisAlignment: widget.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: widget.isUser
                ? [
                    Flexible(child: widget.child),
                    const SizedBox(width: spacingSm),
                    _buildAvatar(colors),
                  ]
                : [
                    _buildAvatar(colors),
                    const SizedBox(width: spacingSm),
                    Flexible(child: widget.child),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ChatColors colors) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: widget.isUser
            ? [colors.userBubble, colors.userBubble.withValues(alpha: 0.7)]
            : [colors.accent, colors.accent.withValues(alpha: 0.7)],
      ),
      boxShadow: [
        BoxShadow(
          color: (widget.isUser ? colors.userBubble : colors.accent)
              .withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      widget.isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
      color: Colors.white,
      size: 20,
    ),
  );
}
