/// Modelli per la Debug Console
library;

/// Tipo di entry nella console
enum ConsoleEntryType {
  system,
  info,
  prompt,
  userInput,
  success,
  error,
  output,
}

/// Singola entry nella history della console
class ConsoleEntry {
  final ConsoleEntryType type;
  final String text;
  final DateTime timestamp;

  ConsoleEntry({
    required this.type,
    required this.text,
  }) : timestamp = DateTime.now();
}

/// Risultato della risoluzione di un valore
class ResolvedValue {
  final dynamic value;
  final bool isLiteral;
  final String? error;

  const ResolvedValue.success(this.value, {this.isLiteral = false}) : error = null;
  const ResolvedValue.error(this.error)
      : value = null,
        isLiteral = false;

  bool get isSuccess => error == null;
  bool get isError => error != null;
}

/// Stato della console debug
enum ConsoleState {
  idle,
  waitingForInput,
  processing,
  completed,
  error,
}

