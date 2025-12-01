/// Eventi del Flowchart BLoC.
/// Rappresentano tutte le operazioni di editing: caricamento, aggiunta/rimozione nodi,
/// collegamenti, modalità connettore, gestione cicli, undo/redo, variabili globali e debug mode.
import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';

abstract class FlowchartEvent extends Equatable {
  const FlowchartEvent();
  @override
  List<Object?> get props => [];
}

class LoadFlowchart extends FlowchartEvent {
  final String fileId;
  final String jsonContent;
  final String fileName;

  const LoadFlowchart(
      {required this.fileId,
      required this.jsonContent,
      required this.fileName});

  @override
  List<Object?> get props => [fileId, jsonContent, fileName];
}

/// Precarica un flowchart in cache senza cambiare il file attivo.
class PreloadFlowchartCache extends FlowchartEvent {
  final String fileId;
  final String fileName;
  final String jsonContent;

  const PreloadFlowchartCache({
    required this.fileId,
    required this.fileName,
    required this.jsonContent,
  });

  @override
  List<Object?> get props => [fileId, fileName, jsonContent];
}

class AddNode extends FlowchartEvent {
  final FlowNodeKind kind;
  final String fromNodeId;
  final String? fromPort;
  final BoxConstraints canvasConstraints;
  final Map<String, dynamic>? initialData;

  const AddNode({
    required this.kind,
    required this.fromNodeId,
    this.fromPort,
    required this.canvasConstraints,
    this.initialData,
  });

  @override
  List<Object?> get props => [kind, fromNodeId, fromPort, canvasConstraints];
}

class RemoveNode extends FlowchartEvent {
  final String nodeId;
  const RemoveNode(this.nodeId);
  @override
  List<Object?> get props => [nodeId];
}

class UpdateNodePosition extends FlowchartEvent {
  final String nodeId;
  final double newX;
  final double newY;
  final double oldX;
  final double oldY;

  const UpdateNodePosition({
    required this.nodeId,
    required this.newX,
    required this.newY,
    required this.oldX,
    required this.oldY,
  });
  @override
  List<Object?> get props => [nodeId, newX, newY, oldX, oldY];
}

class UpdateNodeContent extends FlowchartEvent {
  final String nodeId;
  final Map<String, dynamic> newData;

  const UpdateNodeContent({
    required this.nodeId,
    required this.newData,
  });

  @override
  List<Object?> get props => [nodeId, newData];
}

class SelectNode extends FlowchartEvent {
  final String nodeId;
  const SelectNode(this.nodeId);
  @override
  List<Object?> get props => [nodeId];
}

class DeselectNode extends FlowchartEvent {
  const DeselectNode();
}

class LinkToExistingEnd extends FlowchartEvent {
  final String fromNodeId;
  final String? fromPort;

  const LinkToExistingEnd({required this.fromNodeId, this.fromPort});

  @override
  List<Object?> get props => [fromNodeId, fromPort];
}

class AddGlobalVariable extends FlowchartEvent {
  final VariableDeclaration variable;
  const AddGlobalVariable(this.variable);
  @override
  List<Object> get props => [variable];
}

class UpdateGlobalVariables extends FlowchartEvent {
  final List<VariableDeclaration> variables;
  const UpdateGlobalVariables(this.variables);
  @override
  List<Object> get props => [variables];
}

class UpdateFlowchart extends FlowchartEvent {
  final Flowchart flowchart;

  const UpdateFlowchart(this.flowchart);

  @override
  List<Object> get props => [flowchart];
}

class Undo extends FlowchartEvent {
  const Undo();
}

class Redo extends FlowchartEvent {
  const Redo();
}

class ClearHistory extends FlowchartEvent {}

class ClearFlowchartCache extends FlowchartEvent {}

class ResetCanvasAndVariables extends FlowchartEvent {
  const ResetCanvasAndVariables();
}

class ResetCanvasPreserveVariables extends FlowchartEvent {
  const ResetCanvasPreserveVariables();
}

class AssignmentNodeCreationRequested extends FlowchartEvent {
  final String fromNodeId;
  final String? fromPort;

  const AssignmentNodeCreationRequested({required this.fromNodeId, this.fromPort});

  @override
  List<Object?> get props => [fromNodeId, fromPort];
}

// ===============================================
// ✨ EVENTI PER LA NUOVA FUNZIONALITÀ CONNETTORE ✨
// ===============================================

/// L'utente ha cliccato "Connettore" e vuole iniziare la selezione dei nodi foglia.
class StartConnectorMode extends FlowchartEvent {
  final String fromNodeId;
  const StartConnectorMode(this.fromNodeId);
  @override
  List<Object> get props => [fromNodeId];
}

/// L'utente, in modalità connettore, clicca su un nodo per selezionarlo/deselezionarlo.
class ToggleConnectorNodeSelection extends FlowchartEvent {
  final String nodeId;
  const ToggleConnectorNodeSelection(this.nodeId);
  @override
  List<Object> get props => [nodeId];
}

/// L'utente ha finito di selezionare e ora vuole creare il nodo di destinazione.
class ApplyConnectorAndCreateNode extends FlowchartEvent {
  final FlowNodeKind kind;
  final BoxConstraints canvasConstraints;
  final Map<String, dynamic>? initialData;

  const ApplyConnectorAndCreateNode({
    required this.kind,
    required this.canvasConstraints,
    this.initialData,
  });

  @override
  List<Object?> get props => [kind, canvasConstraints, initialData];
}

/// L'utente vuole annullare l'operazione del connettore.
class CancelConnectorMode extends FlowchartEvent {
  const CancelConnectorMode();
}

/// ✨ Avvia la selezione di UN SOLO nodo per il comando "Resetta da un certo blocco"
class StartResetFromNodeSelection extends FlowchartEvent {
  const StartResetFromNodeSelection();
}

// 🟠 FIX MAGGIORE #7: Evento per gestire il debug mode
/// Imposta o disattiva la modalità debug per bloccare l'editing
class SetDebugMode extends FlowchartEvent {
  final bool isDebugMode;

  const SetDebugMode(this.isDebugMode);

  @override
  List<Object> get props => [isDebugMode];
}

/// Evento per chiudere un ciclo creando un arco di ritorno al nodo loop
class CloseLoop extends FlowchartEvent {
  final String fromNodeId; // Il nodo foglia da cui parte l'arco di ritorno
  final String loopNodeId; // Il nodo loop a cui tornare

  const CloseLoop({
    required this.fromNodeId,
    required this.loopNodeId,
  });

  @override
  List<Object?> get props => [fromNodeId, loopNodeId];
}

/// Evento per selezionare il nodo di partenza del corpo di un ciclo do-while
class SelectDoWhileBodyStart extends FlowchartEvent {
  final String doWhileNodeId; // Il nodo do-while
  final String bodyStartNodeId; // Il nodo selezionato come inizio del corpo

  const SelectDoWhileBodyStart({
    required this.doWhileNodeId,
    required this.bodyStartNodeId,
  });

  @override
  List<Object?> get props => [doWhileNodeId, bodyStartNodeId];
}

/// Evento per avviare la modalità di selezione del corpo do-while
class StartDoWhileBodySelection extends FlowchartEvent {
  final String doWhileNodeId;

  const StartDoWhileBodySelection(this.doWhileNodeId);

  @override
  List<Object?> get props => [doWhileNodeId];
}

/// 🆕 NUOVO: Avvia la modalità connettore per chiudere un ciclo con più nodi foglia
class StartLoopClosureMode extends FlowchartEvent {
  final String loopNodeId; // Il nodo ciclo (while o do-while)

  const StartLoopClosureMode(this.loopNodeId);

  @override
  List<Object?> get props => [loopNodeId];
}

/// 🆕 NUOVO: Applica la chiusura del ciclo collegando i nodi selezionati al ciclo
class ApplyLoopClosure extends FlowchartEvent {
  final String loopNodeId;

  const ApplyLoopClosure(this.loopNodeId);

  @override
  List<Object?> get props => [loopNodeId];
}

/// 🆕 NUOVO: Carica tutti i flowchart del progetto per risolvere le chiamate
class LoadProjectFlowcharts extends FlowchartEvent {
  final Map<String, Flowchart> flowcharts;

  const LoadProjectFlowcharts(this.flowcharts);

  @override
  List<Object?> get props => [flowcharts];
}


class ResetFromNode extends FlowchartEvent {
  final String nodeId;
  const ResetFromNode(this.nodeId);
  @override
  List<Object?> get props => [nodeId];
}
