import 'command_system.dart';
import 'command_registry.dart';

/// Comando HELP - Mostra la lista dei comandi disponibili
class HelpCommand extends ConsoleCommand {
  final CommandRegistry registry;

  HelpCommand(this.registry);

  @override
  String get name => 'help';

  @override
  String get description => 'Mostra la lista dei comandi disponibili';

  @override
  String get usage => 'help [comando]';

  @override
  List<String> get aliases => ['?', 'h'];

  @override
  Future<CommandResult> execute(List<String> args, CommandContext context) async {
    if (args.isEmpty) {
      // Mostra tutti i comandi
      final buffer = StringBuffer();
      buffer.writeln('Comandi disponibili:\n');

      for (final command in registry.allCommands) {
        buffer.write('  ${command.name.padRight(12)} - ${command.description}');
        if (command.aliases.isNotEmpty) {
          buffer.write(' (alias: ${command.aliases.join(", ")})');
        }
        buffer.writeln();
      }

      buffer.writeln('\nUsa "help <comando>" per maggiori dettagli');

      context.onOutput(buffer.toString());
      return const CommandResult.success();
    } else {
      // Mostra dettagli di un comando specifico
      final commandName = args[0].toLowerCase();
      final command = registry.findCommand(commandName);

      if (command == null) {
        return CommandResult.error('Comando "$commandName" non trovato');
      }

      final buffer = StringBuffer();
      buffer.writeln('Dettagli comando: ${command.name}\n');
      buffer.writeln('Descrizione: ${command.description}');
      buffer.writeln('Uso: ${command.usage}');

      if (command.aliases.isNotEmpty) {
        buffer.writeln('Alias: ${command.aliases.join(", ")}');
      }

      context.onOutput(buffer.toString());
      return const CommandResult.success();
    }
  }
}
