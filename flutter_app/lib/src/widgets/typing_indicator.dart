import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/theme/chat_colors.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';

/// Builds an animated typing indicator with bouncing dots and avatar.
Widget buildTypingIndicator(BuildContext context) {
  final colors = Theme.of(context).extension<ChatColors>()!;

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Avatar
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.accent, colors.accent.withValues(alpha: 0.7)],
          ),
          boxShadow: [
            BoxShadow(
              color: colors.accent.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: spacingSm),
      // Bubble with dots
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        decoration: BoxDecoration(
          color: colors.assistantBubble,
          borderRadius: BorderRadius.circular(radiusBubble),
          boxShadow: [
            BoxShadow(
              color: colors.assistantBubble.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _TypingDots(accentColor: colors.accent),
      ),
    ],
  );
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.accentColor});

  final Color accentColor;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      3,
      (index) => _AnimatedDot(
        controller: _controller,
        delay: index * 0.15,
        color: widget.accentColor,
      ),
    ),
  );
}

class _AnimatedDot extends StatelessWidget {
  const _AnimatedDot({
    required this.controller,
    required this.delay,
    required this.color,
  });

  final AnimationController controller;
  final double delay;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final progress = (controller.value + delay) % 1.0;
      final bounce = _bounceValue(progress);
      final scale = 0.7 + bounce * 0.5;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Transform.translate(
          offset: Offset(0, -bounce * 6),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.5 + bounce * 0.5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: bounce * 0.4),
                    blurRadius: 4,
                    spreadRadius: bounce * 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  double _bounceValue(double t) => t < 0.5
      ? 4 * t * t * (3 - 2 * t)
      : 1 - 4 * (1 - t) * (1 - t) * (3 - 2 * (1 - t));
}
