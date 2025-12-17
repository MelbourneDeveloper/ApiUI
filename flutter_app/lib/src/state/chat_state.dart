import 'package:flutter_app/src/models.dart';
import 'package:reflux/reflux.dart';

/// Chat application state.
typedef ChatState = ({
  String? sessionId,
  List<ChatMessage> messages,
  bool isLoading,
  bool isLoadingImage,
});

/// Initial chat state.
const ChatState initialChatState = (
  sessionId: null,
  messages: [],
  isLoading: false,
  isLoadingImage: false,
);

/// Chat actions.
sealed class ChatAction extends Action {
  /// Creates a chat action.
  const ChatAction();
}

/// Session initialized successfully.
final class SessionInitialized extends ChatAction {
  /// Creates a session initialized action.
  const SessionInitialized(this.sessionId);

  /// The session ID.
  final String sessionId;
}

/// Session initialization failed.
final class SessionFailed extends ChatAction {
  /// Creates a session failed action.
  const SessionFailed();
}

/// Start loading (session init or waiting for response).
final class StartLoading extends ChatAction {
  /// Creates a start loading action.
  const StartLoading();
}

/// Stop loading.
final class StopLoading extends ChatAction {
  /// Creates a stop loading action.
  const StopLoading();
}

/// Add a message to the chat.
final class AddMessage extends ChatAction {
  /// Creates an add message action.
  const AddMessage(this.message);

  /// The message to add.
  final ChatMessage message;
}

/// Start loading a large image.
final class StartImageLoading extends ChatAction {
  /// Creates a start image loading action.
  const StartImageLoading();
}

/// Stop loading a large image.
final class StopImageLoading extends ChatAction {
  /// Creates a stop image loading action.
  const StopImageLoading();
}

/// Chat reducer.
ChatState chatReducer(ChatState state, Action action) => switch (action) {
  SessionInitialized(:final sessionId) => (
    sessionId: sessionId,
    messages: state.messages,
    isLoading: false,
    isLoadingImage: state.isLoadingImage,
  ),
  SessionFailed() => (
    sessionId: null,
    messages: state.messages,
    isLoading: false,
    isLoadingImage: state.isLoadingImage,
  ),
  StartLoading() => (
    sessionId: state.sessionId,
    messages: state.messages,
    isLoading: true,
    isLoadingImage: state.isLoadingImage,
  ),
  StopLoading() => (
    sessionId: state.sessionId,
    messages: state.messages,
    isLoading: false,
    isLoadingImage: state.isLoadingImage,
  ),
  AddMessage(:final message) => (
    sessionId: state.sessionId,
    messages: [...state.messages, message],
    isLoading: state.isLoading,
    isLoadingImage: state.isLoadingImage,
  ),
  StartImageLoading() => (
    sessionId: state.sessionId,
    messages: state.messages,
    isLoading: state.isLoading,
    isLoadingImage: true,
  ),
  StopImageLoading() => (
    sessionId: state.sessionId,
    messages: state.messages,
    isLoading: state.isLoading,
    isLoadingImage: false,
  ),
  _ => state,
};

/// Create the chat store.
Store<ChatState> createChatStore() =>
    createStore(chatReducer, initialChatState);
