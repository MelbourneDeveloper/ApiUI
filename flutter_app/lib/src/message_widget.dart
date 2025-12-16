import 'package:flutter/material.dart';
import 'package:flutter_app/src/models.dart';
import 'package:flutter_app/src/services/file_saver_service.dart';
import 'package:flutter_app/src/theme/chat_colors.dart';
import 'package:flutter_app/src/theme/responsive.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';
import 'package:flutter_app/src/widgets/animated_message.dart';
import 'package:flutter_app/src/widgets/chart_widget.dart';
import 'package:flutter_app/src/widgets/message_bubble.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a chat message with its display content.
Widget buildMessageWidget(
  ChatMessage message, {
  required Breakpoint breakpoint,
  required BuildContext context,
}) {
  final isUser = message.role == 'human';

  return AnimatedMessageRow(
    isUser: isUser,
    breakpoint: breakpoint,
    child: Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        buildMessageBubble(
          content: message.content,
          isUser: isUser,
          breakpoint: breakpoint,
          context: context,
          onTapLink: (_, href, _) => _launchUrl(href),
        ),
        ...message.displayItems.map(
          (item) => _buildDisplayContent(item, context: context),
        ),
      ],
    ),
  );
}

Widget _buildDisplayContent(
  DisplayContent content, {
  required BuildContext context,
}) => Padding(
  padding: const EdgeInsets.only(top: spacingSm),
  child: switch (content) {
    TextContent(content: final text) => Text(text),
    ImageContent(url: final url, alt: final alt) => _buildImage(url, alt),
    LinkContent(url: final url, title: final title) => _buildLink(
      url,
      title,
      context: context,
    ),
    ChartContent() => _buildChart(content, context: context),
    FileContent() => _buildFileDownload(content),
    AuthRequiredContent() => _buildAuthRequired(content, context: context),
  },
);

Widget _buildImage(String url, String alt) => ClipRRect(
  borderRadius: BorderRadius.circular(radiusSm),
  child: Image.network(
    url,
    errorBuilder: (_, _, _) => Text('Failed to load image: $alt'),
  ),
);

Widget _buildLink(String url, String title, {required BuildContext context}) {
  final colors = Theme.of(context).extension<ChatColors>()!;

  return InkWell(
    onTap: () => _launchUrl(url),
    borderRadius: BorderRadius.circular(radiusSm),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: spacingXs,
        horizontal: spacingSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: iconSizeSm, color: colors.linkColor),
          const SizedBox(width: spacingXs),
          Text(
            title.isNotEmpty ? title : url,
            style: TextStyle(
              color: colors.linkColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildChart(ChartContent content, {required BuildContext context}) =>
    buildChart(content, context: context);

Widget _buildFileDownload(FileContent file) => OutlinedButton.icon(
  onPressed: () => _saveFile(file),
  icon: const Icon(Icons.download),
  label: Text(file.name),
);

Future<void> _saveFile(FileContent file) =>
    fileSaver(name: file.name, content: file.content);

Widget _buildAuthRequired(
  AuthRequiredContent content, {
  required BuildContext context,
}) {
  final colors = Theme.of(context).extension<ChatColors>()!;

  return Card(
    color: colors.authCardBackground,
    child: Padding(
      padding: const EdgeInsets.all(spacingLg),
      child: Column(
        children: [
          Icon(Icons.lock, size: iconSizeXl, color: colors.accent),
          const SizedBox(height: spacingSm),
          Text('Authentication required for ${content.provider}'),
          const SizedBox(height: spacingSm),
          ElevatedButton(
            onPressed: () => _launchUrl(content.authUrl),
            child: const Text('Sign In'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _launchUrl(String? url) async {
  final uri = url != null ? Uri.tryParse(url) : null;
  switch (uri) {
    case null:
      return;
    case final validUri when await canLaunchUrl(validUri):
      await launchUrl(validUri);
    default:
      return;
  }
}
