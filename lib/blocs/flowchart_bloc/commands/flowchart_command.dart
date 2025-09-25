// Con la nuova architettura, questo file si semplifica enormemente.
// Le vecchie classi di comandi specifici possono essere eliminate.

import 'package:flowchart_repository/flowchart_repository.dart';
import '../flowchart_state.dart';

/// Interfaccia base per tutti i comandi eseguibili.
abstract class FlowchartCommand {
  FlowchartLoaded execute(FlowchartLoaded currentState);
  FlowchartLoaded undo(FlowchartLoaded currentState);
  String get description;
}

/// Un comando che gestisce la transizione atomica da uno stato
/// del flowchart a un altro. Sostituisce tutti i comandi specifici.
class UpdateFlowchartCommand implements FlowchartCommand {
  /// Lo stato del flowchart PRIMA che il comando fosse eseguito.
  final Flowchart oldFlowchart;

  /// Lo stato del flowchart DOPO l'esecuzione del comando.
  final Flowchart newFlowchart;

  @override
  final String description;

  UpdateFlowchartCommand({
    required this.oldFlowchart,
    required this.newFlowchart,
    required this.description,
  });

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    // L'esecuzione semplicemente applica il nuovo stato del flowchart.
    return currentState.copyWith(flowchart: newFlowchart);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    // L'undo ripristina il vecchio stato del flowchart.
    return currentState.copyWith(flowchart: oldFlowchart);
  }
}