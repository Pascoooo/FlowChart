import 'command_system.dart';

/// Comando CLEAR - Pulisce la console
class ClearCommand extends ConsoleCommand {
  @override
  String get name => 'clear';

  @override
  String get description => 'Pulisce lo storico della console';

  @override
  String get usage => 'clear';

  @override
  List<String> get aliases => ['cls'];

  @override
  Future<CommandResult> execute(List<String> args, CommandContext context) async {
    context.onClearHistory();
    return const CommandResult.success(message: 'Console pulita');
  }
}

