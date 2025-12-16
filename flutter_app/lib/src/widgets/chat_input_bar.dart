import 'package:flutter/material.dart';
import 'package:flutter_app/src/theme/chat_colors.dart';
import 'package:flutter_app/src/theme/responsive.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';

/// Builds a floating glassmorphic input bar.
Widget buildChatInputBar({
  required TextEditingController controller,
  required VoidCallback onSend,
  required Breakpoint breakpoint,
  required BuildContext context,
}) {
  final colors = Theme.of(context).extension<ChatColors>()!;

  return Container(
    margin: EdgeInsets.symmetric(
      horizontal: responsivePadding(breakpoint),
      vertical: spacingMd,
    ),
    decoration: BoxDecoration(
      color: colors.inputBackground,
      borderRadius: BorderRadius.circular(radiusPill),
      border: Border.all(color: colors.inputBorder, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: colors.accent.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(color: colors.inputText, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: TextStyle(color: colors.hintText),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: spacingXl,
                vertical: responsive(
                  breakpoint,
                  phone: spacingMd,
                  desktop: spacingLg,
                ),
              ),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        _AnimatedSendButton(onSend: onSend, colors: colors),
      ],
    ),
  );
}

class _AnimatedSendButton extends StatefulWidget {
  const _AnimatedSendButton({required this.onSend, required this.colors});

  final VoidCallback onSend;
  final ChatColors colors;

  @override
  State<_AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<_AnimatedSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: spacingSm, vertical: 6),
    child: GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.colors.sendButton,
                widget.colors.sendButton.withValues(alpha: 0.8),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.colors.sendButton.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.send_rounded,
            color: widget.colors.sendButtonIcon,
            size: iconSizeMd,
          ),
        ),
      ),
    ),
  );
}
