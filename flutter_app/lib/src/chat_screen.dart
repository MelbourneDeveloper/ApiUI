import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/chat_api.dart';
import 'package:flutter_app/src/logging/logging.dart';
import 'package:flutter_app/src/message_widget.dart';
import 'package:flutter_app/src/models.dart';
import 'package:flutter_app/src/oauth_handler.dart';
import 'package:flutter_app/src/state/chat_state.dart';
import 'package:flutter_app/src/theme/responsive.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';
import 'package:flutter_app/src/widgets/chat_app_bar.dart';
import 'package:flutter_app/src/widgets/chat_input_bar.dart';
import 'package:flutter_app/src/widgets/typing_indicator.dart';
import 'package:http/http.dart' as http;
import 'package:nadz/nadz.dart';
import 'package:reflux/reflux.dart';

/// Main chat screen widget.
class ChatScreen extends StatefulWidget {
  /// Creates a chat screen with the given logging context and optional client.
  const ChatScreen({
    required this.logging,
    required this.httpClient,
    this.baseUrl = defaultBaseUrl,
    super.key,
  });

  /// Logging context for API calls.
  final LoggingContext logging;

  /// HTTP client for dependency injection (testing).
  final http.Client httpClient;

  /// Base URL for API calls.
  final String baseUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final Store<ChatState> _store;
  Unsubscribe? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _store = createChatStore();
    _unsubscribe = _store.subscribe(() => setState(() {}));
    unawaited(_initSession());
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    _store.dispatch(const StartLoading());
    final result = await createSession(
      logging: widget.logging,
      client: widget.httpClient,
      baseUrl: widget.baseUrl,
    );
    switch (result) {
      case Success(value: final s):
        _store.dispatch(SessionInitialized(s.id));
      case Error():
        _store.dispatch(const SessionFailed());
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final sessionId = _store.getState().sessionId;
    switch ((text.isNotEmpty, sessionId)) {
      case (true, final String id):
        await _doSend(id, text);
      default:
        return;
    }
  }

  Future<void> _doSend(String sessionId, String text) async {
    _controller.clear();
    _store
      ..dispatch(AddMessage(createChatMessage('human', text)))
      ..dispatch(const StartLoading());
    _scrollToBottom();

    final result = await sendMessage(
      sessionId: sessionId,
      message: text,
      logging: widget.logging,
      client: widget.httpClient,
      baseUrl: widget.baseUrl,
    );

    _store.dispatch(const StopLoading());
    switch (result) {
      case Success(value: final response):
        _store.dispatch(
          AddMessage(
            createChatMessage(
              'assistant',
              response.response,
              displayItems: response.toolOutputs,
            ),
          ),
        );
        _handleAuthRequired(response.toolOutputs);
      case Error(error: final code):
        _store.dispatch(
          AddMessage(createChatMessage('assistant', 'Error: HTTP $code')),
        );
    }
    _scrollToBottom();
  }

  void _handleAuthRequired(List<DisplayContent> items) {
    for (final item in items) {
      switch (item) {
        case AuthRequiredContent(provider: final p, authUrl: final url):
          unawaited(
            handleOAuthRequired(
              context: context,
              provider: p,
              authUrl: url,
            ),
          );
        default:
          break;
      }
    }
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback(
    (_) => _scrollController.hasClients
        ? _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: durationScroll,
            curve: Curves.easeOut,
          )
        : null,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final breakpoint = breakpointFromWidth(constraints.maxWidth);

      return Scaffold(
        appBar: buildChatAppBar(
          title: 'Agent Chat',
          breakpoint: breakpoint,
          context: context,
        ),
        body: _buildBody(breakpoint),
      );
    },
  );

  Widget _buildBody(Breakpoint breakpoint) {
    final maxWidth = responsiveMaxWidth(breakpoint);
    final state = _store.getState();

    return Center(
      child: Container(
        constraints: maxWidth != null
            ? BoxConstraints(maxWidth: maxWidth)
            : null,
        child: Column(
          children: [
            Expanded(child: _buildMessageList(breakpoint, state)),
            _buildLoadingIndicator(breakpoint, state),
            buildChatInputBar(
              controller: _controller,
              onSend: _sendMessage,
              breakpoint: breakpoint,
              context: context,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(Breakpoint breakpoint, ChatState state) =>
      switch (state.sessionId) {
        null => const Center(child: CircularProgressIndicator()),
        _ => ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: spacingMd),
          itemCount: state.messages.length,
          itemBuilder: (context, i) => buildMessageWidget(
            state.messages[i],
            breakpoint: breakpoint,
            context: context,
          ),
        ),
      };

  Widget _buildLoadingIndicator(Breakpoint breakpoint, ChatState state) =>
      switch (state.isLoading) {
        true => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsivePadding(breakpoint),
            vertical: spacingSm,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: buildTypingIndicator(context),
          ),
        ),
        false => const SizedBox.shrink(),
      };
}
