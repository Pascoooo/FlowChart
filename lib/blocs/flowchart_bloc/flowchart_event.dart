import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';

abstract class FlowchartEvent extends Equatable {
  const FlowchartEvent();
  @override
  List<Object?> get props => [];
}

class LoadFlowchart extends FlowchartEvent {
  final String jsonContent;
  final String fileName;

  const LoadFlowchart({required this.jsonContent, required this.fileName});

  @override
  List<Object?> get props => [jsonContent, fileName];
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

class ClearHistory extends FlowchartEvent {
  const ClearHistory();
}

class DebugFlowchart extends FlowchartEvent {
  const DebugFlowchart();
}

class DebugNextNode extends FlowchartEvent {
  const DebugNextNode();
}

class DebugPrevNode extends FlowchartEvent {
  const DebugPrevNode();
}

class DebugExit extends FlowchartEvent {
  const DebugExit();
}

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

class DebugBranchSelected extends FlowchartEvent {
  final bool result; // true -> ramo 'true', false -> ramo 'false'
  const DebugBranchSelected(this.result);
}
