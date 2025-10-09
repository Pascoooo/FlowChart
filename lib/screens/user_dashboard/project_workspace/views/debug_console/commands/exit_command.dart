import 'command_system.dart';

/// Comando EXIT - Esce dalla modalità debug
class ExitCommand extends ConsoleCommand {
  @override
  String get name => 'exit';

  @override
  String get description => 'Esce dalla modalità debug';

  @override
  String get usage => 'exit';

  @override
  List<String> get aliases => ['quit', 'q'];

  @override
  Future<CommandResult> execute(List<String> args, CommandContext context) async {
    context.onExit();
    return const CommandResult.success(message: 'Uscita dalla modalità debug...');
  }
}

