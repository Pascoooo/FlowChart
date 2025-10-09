import 'dart:ui';

import 'command_system.dart';
import 'clear_command.dart';
import 'exit_command.dart';
import 'help_command.dart';
import 'next_command.dart';
import 'prev_command.dart';

/// Registry centrale di tutti i comandi disponibili
class CommandRegistry {
  final Map<String, ConsoleCommand> _commands = {};
  final Map<String, String> _aliases = {};

  CommandRegistry({
    VoidCallback? onNext,
    VoidCallback? onPrev,
  }) {
    // Registra i comandi di sistema
    register(ClearCommand());
    register(ExitCommand());
    register(HelpCommand(this));

    // Registra i comandi di navigazione se i callback sono forniti
    if (onNext != null) {
      register(NextCommand(onNext));
    }
    if (onPrev != null) {
      register(PrevCommand(onPrev));
    }
  }

  /// Registra un nuovo comando
  void register(ConsoleCommand command) {
    _commands[command.name] = command;

    // Registra gli alias
    for (final alias in command.aliases) {
      _aliases[alias] = command.name;
    }
  }

  /// Trova un comando per nome o alias
  ConsoleCommand? findCommand(String nameOrAlias) {
    // Cerca prima per nome diretto
    if (_commands.containsKey(nameOrAlias)) {
      return _commands[nameOrAlias];
    }

    // Cerca per alias
    if (_aliases.containsKey(nameOrAlias)) {
      final commandName = _aliases[nameOrAlias]!;
      return _commands[commandName];
    }

    return null;
  }

  /// Ottiene tutti i comandi registrati
  List<ConsoleCommand> get allCommands => _commands.values.toList();

  /// Esegue un comando parsando l'input dell'utente
  Future<CommandResult> executeCommand(String input, CommandContext context) async {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return const CommandResult.error('Comando vuoto');
    }

    final commandName = parts.first.toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    final command = findCommand(commandName);
    if (command == null) {
      return CommandResult.error('Comando "$commandName" non trovato. Usa "help" per vedere i comandi disponibili.');
    }

    // Valida gli argomenti
    if (!command.validateArgs(args)) {
      return CommandResult.error('Argomenti non validi.\nUso: ${command.usage}');
    }

    try {
      return await command.execute(args, context);
    } catch (e) {
      return CommandResult.error('Errore esecuzione comando: ${e.toString()}');
    }
  }
}
