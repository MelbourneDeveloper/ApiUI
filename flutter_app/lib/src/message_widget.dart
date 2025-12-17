import 'dart:async';

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
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        buildMessageBubble(
          content: message.content,
          isUser: isUser,
          breakpoint: breakpoint,
          context: context,
          onTapLink: (_, href, _) => _launchUrl(href),
        ),
        ..._buildGroupedDisplayItems(message.displayItems, context: context),
      ],
    ),
  );
}

List<Widget> _buildGroupedDisplayItems(
  List<DisplayContent> items, {
  required BuildContext context,
}) {
  final widgets = <Widget>[];
  final imageBuffer = <ImageContent>[];

  void flushImages() {
    if (imageBuffer.isEmpty) return;
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: spacingSm),
        child: _ImageGrid(images: List.of(imageBuffer)),
      ),
    );
    imageBuffer.clear();
  }

  for (final item in items) {
    switch (item) {
      case ImageContent():
        imageBuffer.add(item);
      case _:
        flushImages();
        widgets.add(_buildDisplayContent(item, context: context));
    }
  }
  flushImages();
  return widgets;
}

Widget _buildDisplayContent(
  DisplayContent content, {
  required BuildContext context,
}) => Padding(
  padding: const EdgeInsets.only(top: spacingSm),
  child: switch (content) {
    TextContent(content: final text) => Text(text),
    ImageContent() => _ImageGrid(images: [content]),
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

const _kThumbnailSize = 120.0;

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  final List<ImageContent> images;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: spacingSm,
    runSpacing: spacingSm,
    children: images.map((img) => _ImageThumbnail(image: img)).toList(),
  );
}

const _kImageLoadTimeout = Duration(seconds: 30);

class _ImageThumbnail extends StatefulWidget {
  const _ImageThumbnail({required this.image});

  final ImageContent image;

  @override
  State<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<_ImageThumbnail> {
  bool _isLoading = false;

  Future<void> _onTap() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final largeUrl = widget.image.url.replaceAll('/square.', '/large.');

    try {
      final imageProvider =
          await _preloadImage(largeUrl).timeout(_kImageLoadTimeout);
      if (!mounted) return;
      setState(() => _isLoading = false);
      await _showPreloadedImageDialog(context, imageProvider);
    } on Exception {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorToast(context);
    }
  }

  Future<ImageProvider> _preloadImage(String url) {
    final completer = Completer<ImageProvider>();
    final imageProvider = NetworkImage(url);
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        stream.removeListener(listener);
        completer.complete(imageProvider);
      },
      onError: (error, _) {
        stream.removeListener(listener);
        completer.completeError(error);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  void _showErrorToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to load image'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _onTap,
    child: Container(
      width: _kThumbnailSize,
      height: _kThumbnailSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusSm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.image.url,
              fit: BoxFit.cover,
              width: _kThumbnailSize,
              height: _kThumbnailSize,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const _ImageLoadingIndicator(),
              errorBuilder: (_, _, _) => _ImageErrorIcon(alt: widget.image.alt),
            ),
            if (_isLoading)
              const ColoredBox(
                color: Colors.black54,
                child: _ImageLoadingIndicator(),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showPreloadedImageDialog(
  BuildContext context,
  ImageProvider imageProvider,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(spacingMd),
    child: Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: InteractiveViewer(
            child: Image(image: imageProvider, fit: BoxFit.contain),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ],
    ),
  ),
);

class _ImageLoadingIndicator extends StatelessWidget {
  const _ImageLoadingIndicator();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

class _ImageErrorIcon extends StatelessWidget {
  const _ImageErrorIcon({required this.alt});

  final String alt;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: alt.isNotEmpty ? alt : 'Failed to load',
    child: const Center(
      child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
    ),
  );
}

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
