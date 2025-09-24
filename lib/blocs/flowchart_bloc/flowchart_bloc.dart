import 'dart:async';
import 'dart:ui';
import 'package:bloc/bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../screens/user_dashboard/project_workspace/views/rules/flowchart_rule.dart';
import 'flowchart_event.dart';
import 'flowchart_shape_factory.dart';
import 'flowchart_state.dart';
import 'commands/command_history.dart';
import 'commands/flowchart_command.dart';
import 'placement_engine.dart';

class FlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> {
  final CommandHistory _history = CommandHistory();

  FlowchartBloc() : super(FlowchartInitial()) {
    on<LoadFlowchart>(_onLoadFlowchart);
    on<AddNode>(_onAddNode);
    on<RemoveNode>(_onRemoveNode);
    on<UpdateNodePosition>(_onUpdateNodePosition);
    on<UpdateNodeContent>(_onUpdateNodeContent);
    on<SelectNode>(_onSelectNode);
    on<DeselectNode>(_onDeselectNode);
    on<LinkToExistingEnd>(_onLinkToExistingEnd);
    on<Undo>(_onUndo);
    on<Redo>(_onRedo);
    on<ResetFlowchart>(_onResetFlowchart);
    on<ClearHistory>(_onClearHistory);
  }

  // Getter per la UI per abilitare/disabilitare i pulsanti undo/redo
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    // La logica di preservare la selezione e gestire il nome del file
    // è ora delegata allo stato stesso.
    final loadedState = FlowchartLoaded.fromJson(event.jsonContent);
    final currentSelection = (state is FlowchartLoaded) ? (state as FlowchartLoaded).selectedNodeId : null;

    // Sincronizza il nome del flowchart con il nome del file
    final flowchartWithName = loadedState.flowchart.copyWith(name: event.fileName);

    // Ripristina la selezione se il nodo esiste ancora
    String? finalSelection = currentSelection;
    if (currentSelection != null && !flowchartWithName.nodes.any((n) => n.id == currentSelection)) {
      finalSelection = null;
    }

    emit(loadedState.copyWith(
      flowchart: flowchartWithName,
      selectedNodeId: finalSelection,
    ));
  }

// All'interno della classe FlowchartBloc

  void _onAddNode(AddNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final validator = FlowchartValidator();

    // 1. Usa la factory per creare un nodo potenziale, passando i dati dal dialogo.
    final potentialNode = FlowNodeFactory.createNode(
      event.kind,
      Offset.zero, // La posizione iniziale è temporanea
      initialData: event.initialData, // <-- PASSAGGIO DEI DATI CORRETTO
    );

    // 2. Valida il TIPO di nodo
    var validationResult = validator.validate(currentState, potentialNode);
    if (!validationResult.isValid) {
      emit(FlowchartActionFailure(
        title: "Azione non permessa",
        message: validationResult.errorMessage!,
      ));
      emit(currentState);
      return;
    }

    // 3. Trova il nodo di partenza
    final fromNode = currentState.getNodeById(event.fromNodeId);
    if (fromNode == null) return;

    // 4. Calcola la posizione ottimale
    final optimalPosition = PlacementEngine.findOptimalPosition(
      fromNode: fromNode,
      newNodeSize: Size(potentialNode.width, potentialNode.height),
      existingNodes: currentState.flowchart.nodes,
      canvasConstraints: event.canvasConstraints,
      fromPort: event.fromPort,
    );

    if (optimalPosition == null) {
      emit(const FlowchartActionFailure(
        title: "Posizione non disponibile",
        message: "Non c'è spazio sufficiente per aggiungere un nuovo nodo qui.",
      ));
      emit(currentState);
      return;
    }

    // 5. Applica la posizione finale al nodo (che ha già i dati corretti)
    final newNode = (potentialNode as dynamic).copyWith(x: optimalPosition.dx, y: optimalPosition.dy);
    final newEdge = FlowchartEdge(
      from: fromNode.id,
      to: newNode.id,
      port: event.fromPort,
    );

    // 6. Valida la nuova connessione
    validationResult = validator.validate(currentState, newEdge);
    if (!validationResult.isValid) {
      emit(FlowchartActionFailure(
        title: "Connessione non permessa",
        message: validationResult.errorMessage!,
      ));
      emit(currentState);
      return;
    }

    // 7. Esegui il comando per aggiornare lo stato
    final command = CompositeCommand(
      [AddNodeCommand(newNode), AddEdgeCommand(newEdge)],
      'Aggiungi ${newNode.kind.toString().split('.').last}',
    );

    _history.executeCommand(command);
    emit(command.execute(currentState));
  }

  void _onRemoveNode(RemoveNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final nodeToRemove = currentState.getNodeById(event.nodeId);
    if (nodeToRemove == null) return;

    // CONTROLLO: Impedisce l'eliminazione del nodo Start
    if (nodeToRemove.kind == FlowNodeKind.start) {
      emit(const FlowchartActionFailure(
        title: "Azione non permessa",
        message: "Il nodo 'Inizio' non può essere eliminato.",
      ));
      emit(currentState);
      return;
    }

    // CONTROLLO: Impedisce l'eliminazione di nodi con connessioni in uscita
    if (currentState.getOutgoingEdges(nodeToRemove.id).isNotEmpty) {
      emit(const FlowchartActionFailure(
        title: "Azione non permessa",
        message: "Rimuovi prima le connessioni in uscita da questo nodo.",
      ));
      emit(currentState);
      return;
    }

    // Se un nodo viene rimosso, seleziona il suo "genitore" se ne ha uno solo.
    final incomingEdges = currentState.flowchart.edges.where((e) => e.to == nodeToRemove.id);
    String? parentId;
    if (incomingEdges.length == 1) {
      parentId = incomingEdges.first.from;
    }

    final commands = <FlowchartCommand>[];
    // Rimuovi tutte le connessioni in entrata
    for (final edge in incomingEdges) {
      commands.add(RemoveEdgeCommand(edge));
    }
    // Infine, rimuovi il nodo
    commands.add(RemoveNodeCommand(nodeToRemove));

    final command = CompositeCommand(commands, 'Rimuovi ${nodeToRemove.kind.name}');
    _history.executeCommand(command);

    final newState = command.execute(currentState);

    // Applica la nuova selezione
    if (parentId != null && newState.getNodeById(parentId) != null) {
      emit(newState.copyWith(selectedNodeId: parentId));
    } else {
      emit(newState.deselect());
    }
  }

  void _onUpdateNodePosition(UpdateNodePosition event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final command = MoveNodeCommand(
      nodeId: event.nodeId,
      newX: event.newX, newY: event.newY,
      oldX: event.oldX, oldY: event.oldY,
    );
    // Aggiungi alla history solo se c'è stato un movimento effettivo
    if (command.newX != command.oldX || command.newY != command.oldY) {
      _history.executeCommand(command);
    }
    emit(command.execute(currentState));
  }

  void _onUpdateNodeContent(UpdateNodeContent event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final oldNode = currentState.getNodeById(event.nodeId);
    if (oldNode == null) return;

    final command = UpdateNodeContentCommand(
      nodeId: event.nodeId,
      oldNode: oldNode,
      newData: event.newData,
    );

    _history.executeCommand(command);
    emit(command.execute(currentState));
  }

  void _onLinkToExistingEnd(LinkToExistingEnd event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final fromNode = currentState.getNodeById(event.fromNodeId);
    final endNode = currentState.flowchart.nodes.firstWhere(
          (n) => n.kind == FlowNodeKind.end,
      orElse: () => StartNode(id: '', x:0, y:0, width:0, height:0, text:''), // Placeholder, non verrà mai usato
    );

    if (fromNode == null || endNode.id.isEmpty) return;

    // CONTROLLO: Evita connessioni duplicate
    final alreadyLinked = currentState.flowchart.edges.any(
            (e) => e.from == fromNode.id && e.to == endNode.id && e.port == event.fromPort
    );
    if(alreadyLinked) return;

    final newEdge = FlowchartEdge(
      from: fromNode.id,
      to: endNode.id,
      port: event.fromPort,
    );

    final validator = FlowchartValidator();
    final validationResult = validator.validate(currentState, newEdge);

    if (!validationResult.isValid) {
      emit(FlowchartActionFailure(
        title: "Connessione non permessa",
        message: validationResult.errorMessage!,
      ));
      emit(currentState);
      return;
    }

    final command = AddEdgeCommand(newEdge);
    _history.executeCommand(command);
    emit(command.execute(currentState));
  }

  void _onSelectNode(SelectNode event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      emit((state as FlowchartLoaded).copyWith(selectedNodeId: event.nodeId));
    }
  }

  void _onDeselectNode(DeselectNode event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      emit((state as FlowchartLoaded).deselect());
    }
  }

  void _onUndo(Undo event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      final command = _history.undo();
      if (command != null) {
        emit(command.undo(state as FlowchartLoaded));
      }
    }
  }

  void _onRedo(Redo event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      final command = _history.redo();
      if (command != null) {
        emit(command.execute(state as FlowchartLoaded));
      }
    }
  }

  void _onResetFlowchart(ResetFlowchart event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    // Trova il nodo start o creane uno nuovo
    FlowNode startNode;
    try {
      startNode = currentState.flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.start);
    } catch (_) {
      startNode = FlowNodeFactory.createNode(FlowNodeKind.start, const Offset(120, 120));
    }

    _history.clear();

    final newFlowchart = currentState.flowchart.copyWith(
      nodes: [startNode],
      edges: [],
    );

    emit(FlowchartLoaded(
      flowchart: newFlowchart,
      selectedNodeId: startNode.id,
    ));
  }

  void _onClearHistory(ClearHistory event, Emitter<FlowchartState> emit) {
    _history.clear();
  }
}