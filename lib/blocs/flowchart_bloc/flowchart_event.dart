import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';

abstract class FlowchartEvent extends Equatable {
  const FlowchartEvent();
  @override
  List<Object?> get props => [];
}

/// Carica un flowchart da una stringa JSON. (Invariato)
class LoadFlowchart extends FlowchartEvent {
  final String jsonContent;
  final String fileName;

  const LoadFlowchart({required this.jsonContent, required this.fileName});

  @override
  List<Object?> get props => [jsonContent, fileName];
}

/// Aggiunge un nuovo nodo al diagramma.
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

/// Rimuove un nodo e le connessioni associate.
class RemoveNode extends FlowchartEvent {
  final String nodeId;
  const RemoveNode(this.nodeId);
  @override
  List<Object?> get props => [nodeId];
}

/// Aggiorna la posizione (x, y) di un nodo.
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

/// Aggiorna il contenuto specifico di un nodo (es. testo, codice, condizione).
/// Questo evento è più flessibile e potente del vecchio UpdateShapeProperties.
class UpdateNodeContent extends FlowchartEvent {
  final String nodeId;
  // Usiamo una mappa per passare i dati specifici del nodo.
  // Esempi:
  // {'text': 'Nuovo testo'} per aggiornare l'etichetta di qualsiasi nodo.
  // {'code': 'x = x + 1'} per un ProcessNode.
  // {'condition': 'x > 10'} per un DecisionNode.
  final Map<String, dynamic> newData;

  const UpdateNodeContent({
    required this.nodeId,
    required this.newData,
  });

  @override
  List<Object?> get props => [nodeId, newData];
}


/// Seleziona un nodo per l'interazione.
class SelectNode extends FlowchartEvent {
  final String nodeId;
  const SelectNode(this.nodeId);
  @override
  List<Object?> get props => [nodeId];
}

/// Deseleziona qualsiasi nodo attualmente selezionato.
class DeselectNode extends FlowchartEvent {
  const DeselectNode();
}

/// Collega un nodo di partenza a un nodo 'End' già esistente.
class LinkToExistingEnd extends FlowchartEvent {
  final String fromNodeId;
  final String? fromPort; // per DecisionNode

  const LinkToExistingEnd({required this.fromNodeId, this.fromPort});

  @override
  List<Object?> get props => [fromNodeId, fromPort];
}

// --- Eventi per la gestione della cronologia e dello stato globale ---

class Undo extends FlowchartEvent { const Undo(); }
class Redo extends FlowchartEvent { const Redo(); }
class ResetFlowchart extends FlowchartEvent { const ResetFlowchart(); }
class ClearHistory extends FlowchartEvent { const ClearHistory(); }