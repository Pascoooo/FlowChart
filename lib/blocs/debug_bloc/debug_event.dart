import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

abstract class DebugEvent extends Equatable {
  const DebugEvent();

  @override
  List<Object?> get props => [];
}

/// Inizia una sessione di debug
///
/// NOTA: Il debugPath viene costruito internamente dal DebugBloc
/// basandosi sulla topologia del flowchart. La UI non conosce questa logica.
class DebugStart extends DebugEvent {
  final Flowchart flowchart;
  final Map<String, Flowchart> projectFlowcharts;

  const DebugStart({
    required this.flowchart,
    required this.projectFlowcharts,
  });

  @override
  List<Object?> get props => [flowchart, projectFlowcharts];
}

/// Resetta il flag isFirstStep dopo il primo render/zoom
class DebugResetFirstStep extends DebugEvent {
  const DebugResetFirstStep();
}

/// Esegue il prossimo step
///
/// Comportamento:
/// 1. Repository esegue il nodo corrente
/// 2. Variabili vengono aggiornate IMMEDIATAMENTE
/// 3. Se richiede input: emetti DebugAwaitingInput (non avanzare)
/// 4. Se è fine percorso: emetti DebugCompleted
/// 5. Altrimenti: emetti DebugInProgress sul nodo successivo
class DebugNext extends DebugEvent {
  final bool isAutoStart;
  final Flowchart? initialFlowchart;
  final Map<String, Flowchart>? initialProjectFlowcharts;

  const DebugNext({
    this.isAutoStart = false,
    this.initialFlowchart,
    this.initialProjectFlowcharts,
  });

  @override
  List<Object?> get props => [isAutoStart, initialFlowchart, initialProjectFlowcharts];
}

/// Torna al passo precedente (undo)
class DebugPrevious extends DebugEvent {
  const DebugPrevious();
}

/// Termina la sessione di debug
class DebugStop extends DebugEvent {
  const DebugStop();
}

/// Valuta una decisione e sceglie il branch
class DebugEvaluateDecision extends DebugEvent {
  final DecisionNode node;
  final bool result;

  const DebugEvaluateDecision({
    required this.node,
    required this.result,
  });

  @override
  List<Object?> get props => [node, result];
}

/// Aggiorna le variabili (input utente durante runtime assignment)
class DebugUpdateVariables extends DebugEvent {
  final Map<String, dynamic> variables;

  const DebugUpdateVariables(this.variables);

  @override
  List<Object?> get props => [variables];
}

/// Step into un sottoprogramma
class DebugStepInto extends DebugEvent {
  final ProcessNode node;

  const DebugStepInto(this.node);

  @override
  List<Object?> get props => [node];
}

/// Step out da un sottoprogramma
class DebugStepOut extends DebugEvent {
  final dynamic returnValue;

  const DebugStepOut({this.returnValue});

  @override
  List<Object?> get props => [returnValue];
}