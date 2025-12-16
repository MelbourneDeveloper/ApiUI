/// Data models for the chat application.
library;

/// A chat message with content that may include display elements.
typedef ChatMessage = ({
  String role,
  String content,
  List<DisplayContent> displayItems,
});

/// Display content returned by agent tools.
sealed class DisplayContent {
  const DisplayContent();

  factory DisplayContent.fromJson(Map<String, dynamic> json) =>
      switch (json['type']) {
        'image' => ImageContent(
          url: json['url'] as String,
          alt: json['alt'] as String? ?? '',
        ),
        'link' => LinkContent(
          url: json['url'] as String,
          title: json['title'] as String? ?? '',
        ),
        'chart' => ChartContent(
          chartType: json['chart_type'] as String,
          data: (json['data'] as List).cast<Map<String, dynamic>>(),
          title: json['title'] as String? ?? '',
          xLabel: json['x_label'] as String? ?? '',
          yLabel: json['y_label'] as String? ?? '',
        ),
        'file' => FileContent(
          name: json['name'] as String,
          content: json['content'] as String,
          mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
        ),
        'auth_required' => AuthRequiredContent(
          provider: json['provider'] as String,
          authUrl: json['auth_url'] as String,
        ),
        _ => TextContent(content: json.toString()),
      };
}

/// Plain text content.
final class TextContent extends DisplayContent {
  const TextContent({required this.content});
  final String content;
}

/// Image content.
final class ImageContent extends DisplayContent {
  const ImageContent({required this.url, this.alt = ''});
  final String url;
  final String alt;
}

/// Link content.
final class LinkContent extends DisplayContent {
  const LinkContent({required this.url, this.title = ''});
  final String url;
  final String title;
}

/// Chart content.
final class ChartContent extends DisplayContent {
  const ChartContent({
    required this.chartType,
    required this.data,
    this.title = '',
    this.xLabel = '',
    this.yLabel = '',
  });
  final String chartType;
  final List<Map<String, dynamic>> data;
  final String title;
  final String xLabel;
  final String yLabel;
}

/// File content.
final class FileContent extends DisplayContent {
  const FileContent({
    required this.name,
    required this.content,
    this.mimeType = 'application/octet-stream',
  });
  final String name;
  final String content;
  final String mimeType;
}

/// Auth required signal.
final class AuthRequiredContent extends DisplayContent {
  const AuthRequiredContent({required this.provider, required this.authUrl});
  final String provider;
  final String authUrl;
}

/// Session information.
typedef SessionInfo = ({String id, int messageCount});

/// Chat response from the server.
typedef ChatResponse = ({
  String sessionId,
  String response,
  List<DisplayContent> toolOutputs,
});

/// Create a chat message.
ChatMessage createChatMessage(
  String role,
  String content, {
  List<DisplayContent>? displayItems,
}) => (role: role, content: content, displayItems: displayItems ?? []);
