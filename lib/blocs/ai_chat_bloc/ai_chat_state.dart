import 'package:equatable/equatable.dart';

/// Modello per un singolo messaggio
class ChatMessage extends Equatable {
  final String content;
  final bool isUser; // true = utente, false = AI
  final DateTime timestamp;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [content, isUser, timestamp];
}

abstract class AiChatState extends Equatable {
  const AiChatState();

  @override
  List<Object?> get props => [];
}

/// Stato iniziale
class AiChatInitial extends AiChatState {
  const AiChatInitial();
}

/// Chat pronta con cronologia messaggi
class AiChatReady extends AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  const AiChatReady({
    this.messages = const [],
    this.isLoading = false,
  });

  AiChatReady copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return AiChatReady(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [messages, isLoading];
}

/// Errore nella comunicazione con l'AI
class AiChatError extends AiChatState {
  final String errorMessage;
  final List<ChatMessage> messages; // Mantiene la cronologia anche in caso di errore

  const AiChatError({
    required this.errorMessage,
    this.messages = const [],
  });

  @override
  List<Object?> get props => [errorMessage, messages];
}

