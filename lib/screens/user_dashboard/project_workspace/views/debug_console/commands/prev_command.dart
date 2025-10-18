import 'package:flutter/foundation.dart';
import 'command_system.dart';

/// Comando PREV - Torna al nodo precedente del debug
class PrevCommand extends ConsoleCommand {
  final VoidCallback onPrev;

  PrevCommand(this.onPrev);

  @override
  String get name => 'prev';

  @override
  String get description => 'Torna al passo precedente del debug';

  @override
  String get usage => 'prev';

  @override
  List<String> get aliases => ['p', 'back'];

  @override
  Future<CommandResult> execute(List<String> args, CommandContext context) async {
    onPrev();
    return const CommandResult.success(message: 'Tornato al passo precedente');
  }
}

/// Comando NEXT - Avanza al prossimo nodo del debug
class NextCommand extends ConsoleCommand {
  final VoidCallback onNext;

  NextCommand(this.onNext);

  @override
  String get name => 'next';

  @override
  String get description => 'Avanza al prossimo step del debug';

  @override
  String get usage => 'next';

  @override
  List<String> get aliases => ['n', 'forward'];

  @override
  Future<CommandResult> execute(List<String> args, CommandContext context) async {
    // Prima esegui il nodo corrente, poi avanza
    onNext();
    return const CommandResult.success(message: 'Avanzato al prossimo step');
  }
}
