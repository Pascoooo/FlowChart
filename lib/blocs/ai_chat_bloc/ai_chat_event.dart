import 'package:equatable/equatable.dart';

sealed class AiChatEvent extends Equatable {
  const AiChatEvent();

  @override
  List<Object?> get props => [];
}

/// Evento per inviare un messaggio all'AI
final class SendMessageToAi extends AiChatEvent {
  final String message;
  final String? context;

  const SendMessageToAi(this.message, {this.context});

  @override
  List<Object?> get props => [message, context];
}

/// Evento per cancellare la cronologia della chat
final class ClearChatHistory extends AiChatEvent {
  const ClearChatHistory();
}

/// Evento per inizializzare la chat con un messaggio di benvenuto
final class InitializeChat extends AiChatEvent {
  const InitializeChat();
}

