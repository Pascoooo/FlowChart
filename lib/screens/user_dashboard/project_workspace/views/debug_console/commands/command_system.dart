/// Sistema di comandi per la Debug Console
library;

/// Risultato dell'esecuzione di un comando
class CommandResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const CommandResult.success({this.message, this.data})
      : success = true;

  const CommandResult.error(this.message)
      : success = false,
        data = null;
}

/// Interfaccia per un comando della console
abstract class ConsoleCommand {
  /// Nome del comando (es. 'clear', 'exit', 'help')
  String get name;

  /// Descrizione breve del comando
  String get description;

  /// Sintassi del comando con esempi
  String get usage;

  /// Alias del comando (opzionali)
  List<String> get aliases => [];

  /// Esegue il comando
  Future<CommandResult> execute(List<String> args, CommandContext context);

  /// Valida gli argomenti prima dell'esecuzione
  bool validateArgs(List<String> args) => true;
}

/// Contesto di esecuzione per i comandi
class CommandContext {
  final Function(String) onOutput;
  final Function(String) onError;
  final Function() onClearHistory;
  final Function() onExit;
  final Map<String, dynamic> sessionVariables;
  final dynamic projectRepo;
  final String flowchartId;

  CommandContext({
    required this.onOutput,
    required this.onError,
    required this.onClearHistory,
    required this.onExit,
    required this.sessionVariables,
    required this.projectRepo,
    required this.flowchartId,
  });
}

