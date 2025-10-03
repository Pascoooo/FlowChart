import 'package:bloc/bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';
import '../../screens/user_dashboard/project_workspace/views/rules/flowchart_rule.dart';
import 'commands/command_history.dart';
import 'commands/flowchart_command.dart';
import 'flowchart_event.dart';
import 'flowchart_shape_factory.dart';
import 'flowchart_state.dart';
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
    on<ResetCanvasAndVariables>(_onResetCanvasAndVariables);
    on<ResetCanvasPreserveVariables>(_onResetCanvasPreserveVariables);
    on<ClearHistory>(_onClearHistory);
    on<DebugFlowchart>(_onDebugFlowchart);
    on<DebugNextNode>(_onDebugNext);
    on<DebugPrevNode>(_onDebugPrev);
    on<DebugExit>(_onDebugExit);
    on<AddGlobalVariable>(_onAddGlobalVariable);
    on<UpdateGlobalVariables>(_onUpdateGlobalVariables);
    on<AssignmentNodeCreationRequested>(_onAssignmentNodeCreationRequested);

    // =========================================================
    // ✨ REGISTRAZIONE DEI NUOVI EVENTI PER IL CONNETTORE ✨
    // =========================================================
    on<StartConnectorMode>(_onStartConnectorMode);
    on<ToggleConnectorNodeSelection>(_onToggleConnectorNodeSelection);
    on<ApplyConnectorAndCreateNode>(_onApplyConnectorAndCreateNode);
    on<CancelConnectorMode>(_onCancelConnectorMode);
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void _onAssignmentNodeCreationRequested(
      AssignmentNodeCreationRequested event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final assignableVariableNames = currentState.flowchart.nodes
        .whereType<InputNode>()
        .expand((node) => node.targetVariables)
        .toSet();

    if (assignableVariableNames.isEmpty) {
      emit(const FlowchartActionFailure(
        title: 'Nessuna Variabile Disponibile',
        message:
        'Per usare un nodo di Assegnazione, devi prima inserire un nodo di Input e specificare quali variabili può usare.',
      ));
      emit(currentState);
      return;
    }

    final availableVariables = currentState.flowchart.variables
        .where((v) => assignableVariableNames.contains(v.name))
        .toList();

    emit(ShowNodeCreationDialog(
      kind: FlowNodeKind.assignment,
      fromNodeId: event.fromNodeId,
      fromPort: event.fromPort,
      availableVariables: availableVariables,
    ));
    emit(currentState);
  }

  void _onAddGlobalVariable(
      AddGlobalVariable event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    if (currentState.flowchart.variables
        .any((v) => v.name == event.variable.name)) {
      debugPrint('Errore: una variabile con questo nome esiste già.');
      return;
    }

    final newVariables = [...currentState.flowchart.variables, event.variable];
    final newFlowchart =
    currentState.flowchart.copyWith(variables: newVariables);

    emit(currentState.copyWith(flowchart: newFlowchart));
  }

  void _onUpdateGlobalVariables(
      UpdateGlobalVariables event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final newFlowchart =
    currentState.flowchart.copyWith(variables: event.variables);
    emit(currentState.copyWith(flowchart: newFlowchart));
  }

  FlowNode _createUpdatedNode(FlowNode oldNode, Map<String, dynamic> newData,
      FlowchartLoaded currentState) {
    if (oldNode is InputNode) {
      final targetVars = (newData['targetVariables'] as List?)?.cast<String>();
      return oldNode.copyWith(targetVariables: targetVars);
    }

    else if (oldNode is AssignmentNode) {
      final assignmentsData = newData['assignments'] as List?;
      final newAssignments = assignmentsData
          ?.map((a) => Assignment.fromMap(a as Map<String, dynamic>))
          .toList();
      return oldNode.copyWith(assignments: newAssignments);
    }

    else if (oldNode is ProcessNode) {
      return oldNode.copyWith(
        flowchartToCall: newData['flowchartToCall'] as String?,
        arguments: (newData['arguments'] as List?)?.cast<String>(),
        resultTarget: newData['resultTarget'] as String?,
      );
    }

    else if (oldNode is DecisionNode) {
      return oldNode.copyWith(condition: newData['condition'] as String?);
    }

    else if (oldNode is OutputNode) {
      final variableNames = (newData['variables'] as List?)?.cast<String>();

      List<VariableDeclaration>? resolvedVariables;
      if (variableNames != null) {
        resolvedVariables = variableNames.map((name) {
          return currentState.flowchart.variables.firstWhere(
                (v) => v.name == name,
            orElse: () => VariableDeclaration(name: name, dataType: 'unknown'),
          );
        }).toList();
      }

      return oldNode.copyWith(
        template: newData['template'] as String?,
        variables: resolvedVariables,
      );
    }

    return oldNode;
  }

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    _history.clear();
    final loadedState = FlowchartLoaded.fromJson(event.jsonContent);
    final currentSelection = (state is FlowchartLoaded)
        ? (state as FlowchartLoaded).selectedNodeId
        : null;
    final flowchartWithName =
    loadedState.flowchart.copyWith(name: event.fileName);
    String? finalSelection = currentSelection;
    if (currentSelection != null &&
        !flowchartWithName.nodes.any((n) => n.id == currentSelection)) {
      finalSelection = null;
    }
    emit(loadedState.copyWith(
        flowchart: flowchartWithName, selectedNodeId: finalSelection));
  }

  void _onAddNode(AddNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final validator = FlowchartValidator();

    final potentialNode = FlowNodeFactory.createNode(
      event.kind,
      Offset.zero,
      allVariables: currentState.flowchart.variables,
      initialData: event.initialData,
    );

    var validationResult = validator.validate(currentState, potentialNode);
    if (!validationResult.isValid) {
      emit(FlowchartActionFailure(
        title: "Azione non permessa",
        message: validationResult.errorMessage!,
      ));
      emit(currentState);
      return;
    }

    final fromNode = currentState.getNodeById(event.fromNodeId);
    if (fromNode == null) return;

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

    final newNode = (potentialNode as dynamic)
        .copyWith(x: optimalPosition.dx, y: optimalPosition.dy) as FlowNode;
    final newEdge =
    FlowchartEdge(from: fromNode.id, to: newNode.id, port: event.fromPort);

    validationResult = validator.validate(currentState, newEdge);
    if (!validationResult.isValid) {
      emit(FlowchartActionFailure(
        title: "Connessione non permessa",
        message: validationResult.errorMessage!,
      ));
      emit(currentState);
      return;
    }

    final newNodes = [...currentState.flowchart.nodes, newNode];
    final newEdges = [...currentState.flowchart.edges, newEdge];

    final newFlowchart =
    currentState.flowchart.copyWith(nodes: newNodes, edges: newEdges);

    final command = UpdateFlowchartCommand(
      oldFlowchart: currentState.flowchart,
      newFlowchart: newFlowchart,
      description: 'Aggiungi nodo ${newNode.kind.name}',
    );
    _history.executeCommand(command);

    emit(command.execute(currentState).copyWith(selectedNodeId: newNode.id));
  }

  void _onRemoveNode(RemoveNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final nodeToRemove = currentState.getNodeById(event.nodeId);
    if (nodeToRemove == null) return;

    if (nodeToRemove.kind == FlowNodeKind.start) {
      emit(const FlowchartActionFailure(
          title: "Azione non permessa",
          message: "Il nodo 'Inizio' non può essere eliminato."));
      emit(currentState);
      return;
    }

    if (currentState.getOutgoingEdges(nodeToRemove.id).isNotEmpty) {
      emit(const FlowchartActionFailure(
          title: "Azione non permessa",
          message: "Rimuovi prima le connessioni in uscita da questo nodo."));
      emit(currentState);
      return;
    }

    final incomingEdges = currentState.flowchart.edges
        .where((e) => e.to == nodeToRemove.id)
        .toList();
    String? parentId;
    if (incomingEdges.length == 1) {
      parentId = incomingEdges.first.from;
    }

    final newNodes =
    currentState.flowchart.nodes.where((n) => n.id != event.nodeId).toList();
    final newEdges = currentState.flowchart.edges
        .where((e) => e.to != event.nodeId && e.from != event.nodeId)
        .toList();

    final newFlowchart =
    currentState.flowchart.copyWith(nodes: newNodes, edges: newEdges);

    final command = UpdateFlowchartCommand(
      oldFlowchart: currentState.flowchart,
      newFlowchart: newFlowchart,
      description: 'Rimuovi nodo',
    );
    _history.executeCommand(command);

    emit(command
        .execute(currentState)
        .copyWith(selectedNodeId: parentId, clearSelection: parentId == null));
  }

  void _onUpdateNodeContent(
      UpdateNodeContent event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final oldNode = currentState.getNodeById(event.nodeId);
    if (oldNode == null) return;

    final updatedNode = _createUpdatedNode(oldNode, event.newData, currentState);
    final newNodes = currentState.flowchart.nodes
        .map((n) => n.id == event.nodeId ? updatedNode : n)
        .toList();

    final newFlowchart = currentState.flowchart.copyWith(nodes: newNodes);

    final command = UpdateFlowchartCommand(
      oldFlowchart: currentState.flowchart,
      newFlowchart: newFlowchart,
      description: 'Aggiorna contenuto nodo',
    );
    _history.executeCommand(command);

    emit(command.execute(currentState));
  }

  void _onUpdateNodePosition(
      UpdateNodePosition event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final newNodes = currentState.flowchart.nodes.map((n) {
      if (n.id == event.nodeId) {
        return (n as dynamic).copyWith(x: event.newX, y: event.newY) as FlowNode;
      }
      return n;
    }).toList();
    final newFlowchart = currentState.flowchart.copyWith(nodes: newNodes);

    final command = UpdateFlowchartCommand(
      oldFlowchart: currentState.flowchart,
      newFlowchart: newFlowchart,
      description: 'Sposta nodo',
    );
    if (event.newX != event.oldX || event.newY != event.oldY) {
      _history.executeCommand(command);
    }

    emit(command.execute(currentState));
  }

  void _onLinkToExistingEnd(
      LinkToExistingEnd event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final fromNode = currentState.getNodeById(event.fromNodeId);
    if (fromNode == null) return;
    final endNode =
    currentState.flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.end);
    final alreadyLinked = currentState.flowchart.edges.any(
            (e) => e.from == fromNode.id && e.to == endNode.id && e.port == event.fromPort);
    if (alreadyLinked) return;

    final newEdge =
    FlowchartEdge(from: fromNode.id, to: endNode.id, port: event.fromPort);
    final newFlowchart = currentState.flowchart
        .copyWith(edges: [...currentState.flowchart.edges, newEdge]);

    final command = UpdateFlowchartCommand(
        oldFlowchart: currentState.flowchart,
        newFlowchart: newFlowchart,
        description: 'Collega a Fine');
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

  void _onResetCanvasAndVariables(
      ResetCanvasAndVariables event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    _history.clear();

    FlowNode startNode;
    try {
      startNode = currentState.flowchart.nodes
          .firstWhere((n) => n.kind == FlowNodeKind.start);
    } catch (_) {
      startNode = FlowNodeFactory.createNode(
        FlowNodeKind.start,
        const Offset(1030, 50),
        allVariables: [],
      );
    }

    final newFlowchart = currentState.flowchart.copyWith(
      nodes: [startNode],
      edges: <FlowchartEdge>[],
      variables: <VariableDeclaration>[],
    );

    emit(FlowchartLoaded(
      flowchart: newFlowchart,
      selectedNodeId: startNode.id,
    ));
  }

  void _onResetCanvasPreserveVariables(
      ResetCanvasPreserveVariables event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    _history.clear();

    FlowNode startNode;
    try {
      startNode = currentState.flowchart.nodes
          .firstWhere((n) => n.kind == FlowNodeKind.start);
    } catch (_) {
      startNode = FlowNodeFactory.createNode(
        FlowNodeKind.start,
        const Offset(1030, 50),
        allVariables: [],
      );
    }

    final newFlowchart = currentState.flowchart.copyWith(
      nodes: [startNode],
      edges: <FlowchartEdge>[],
      variables: currentState.flowchart.variables,
    );

    emit(FlowchartLoaded(
      flowchart: newFlowchart,
      selectedNodeId: startNode.id,
    ));
  }

  void _onClearHistory(ClearHistory event, Emitter<FlowchartState> emit) {
    _history.clear();
  }

  void _onDebugFlowchart(DebugFlowchart event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    FlowNode? start;
    try {
      start = s.flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.start);
    } catch (_) {
      return;
    }

    final List<String> path = [];
    final visited = <String>{};

    String? currentId = start.id;
    while (currentId != null && currentId.isNotEmpty && !visited.contains(currentId)) {
      path.add(currentId);
      visited.add(currentId);

      final outgoing =
      s.flowchart.edges.where((e) => e.from == currentId).toList();
      if (outgoing.isEmpty) break;

      FlowchartEdge? next;
      next = outgoing.firstWhere(
            (e) => e.port == null,
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );
      if (next.from.isEmpty) {
        next = outgoing.firstWhere(
              (e) => e.port == 'true',
          orElse: () => const FlowchartEdge(from: '', to: ''),
        );
        if (next.from.isEmpty) {
          next = outgoing.firstWhere(
                (e) => e.port == 'false',
            orElse: () => const FlowchartEdge(from: '', to: ''),
          );
        }
      }

      if (next.from.isEmpty) break;
      currentId = next.to;
    }

    if (path.isEmpty) return;

    // ⚠️ MODIFICA: Imposta isDebugJustStarted = true quando inizia la debug mode
    emit(s.copyWith(
      isDebugMode: true,
      debugPath: path,
      debugIndex: 0,
      selectedNodeId: path.first,
      isDebugJustStarted: true, // ⚠️ NUOVO: Zoom SOLO all'inizio
    ));
  }

  void _onDebugNext(DebugNextNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode || s.debugPath.isEmpty) return;

    final nextIndex = (s.debugIndex + 1).clamp(0, s.debugPath.length - 1);
    if (nextIndex == s.debugIndex) return;

    final newNodeId = s.debugPath[nextIndex];
    // ⚠️ MODIFICA: Imposta isDebugJustStarted = false quando si naviga
    emit(s.copyWith(
      debugIndex: nextIndex,
      selectedNodeId: newNodeId,
      isDebugJustStarted: false, // ⚠️ NUOVO: Disabilita lo zoom durante la navigazione
    ));
  }

  void _onDebugPrev(DebugPrevNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode || s.debugPath.isEmpty) return;

    final prevIndex = (s.debugIndex - 1).clamp(0, s.debugPath.length - 1);
    if (prevIndex == s.debugIndex) return;

    final newNodeId = s.debugPath[prevIndex];
    // ⚠️ MODIFICA: Imposta isDebugJustStarted = false quando si naviga
    emit(s.copyWith(
      debugIndex: prevIndex,
      selectedNodeId: newNodeId,
      isDebugJustStarted: false, // ⚠️ NUOVO: Disabilita lo zoom durante la navigazione
    ));
  }

  void _onDebugExit(DebugExit event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    emit(s.copyWith(
      isDebugMode: false,
      debugPath: const [],
      debugIndex: 0,
      isDebugJustStarted: false, // ⚠️ NUOVO: Reset quando si esce dalla debug mode
    ));
  }

  // =============================================================
  // ✨ NUOVI METODI PER LA GESTIONE DELLA LOGICA DEL CONNETTORE ✨
  // =============================================================

  void _onStartConnectorMode(
      StartConnectorMode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    // Pre-seleziona automaticamente il nodo di origine
    emit(currentState.copyWith(
      isConnectorModeActive: true,
      connectorSourceNodeId: event.fromNodeId,
      selectedConnectorNodeIds: {event.fromNodeId}, // Pre-seleziona il nodo di origine
      clearSelection: true,
    ));
  }

  void _onToggleConnectorNodeSelection(
      ToggleConnectorNodeSelection event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    if (!currentState.isConnectorModeActive) return;

    final newSelectedIds =
    Set<String>.from(currentState.selectedConnectorNodeIds);
    if (newSelectedIds.contains(event.nodeId)) {
      newSelectedIds.remove(event.nodeId); // Deseleziona
    } else {
      newSelectedIds.add(event.nodeId); // Seleziona
    }

    emit(currentState.copyWith(selectedConnectorNodeIds: newSelectedIds));
  }

  void _onCancelConnectorMode(
      CancelConnectorMode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    // Resetta completamente lo stato della modalità connettore
    emit(currentState.copyWith(
      isConnectorModeActive: false,
      clearConnectorSource: true,
      selectedConnectorNodeIds: {},
    ));
  }

  void _onApplyConnectorAndCreateNode(
      ApplyConnectorAndCreateNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    if (!currentState.isConnectorModeActive ||
        currentState.connectorSourceNodeId == null) return;

    // 1. Raccoglie tutti gli ID dei nodi sorgente
    final sourceNodeIds = {
      currentState.connectorSourceNodeId!,
      ...currentState.selectedConnectorNodeIds
    };

    final sourceNodes = sourceNodeIds
        .map((id) => currentState.getNodeById(id))
        .whereType<FlowNode>()
        .toList();
    if (sourceNodes.isEmpty) {
      // Sicurezza: se non ci sono nodi validi, annulla l'operazione
      add(const CancelConnectorMode());
      return;
    }

    // 2. Crea il nuovo nodo di destinazione (senza posizione iniziale)
    final newNode = FlowNodeFactory.createNode(
      event.kind,
      Offset.zero,
      allVariables: currentState.flowchart.variables,
      initialData: event.initialData,
    );

    // 3. Calcola una posizione ottimale per il nuovo nodo
    final avgX =
        sourceNodes.map((n) => n.x).reduce((a, b) => a + b) / sourceNodes.length;
    final maxY = sourceNodes
        .map((n) => n.y + n.height)
        .reduce((a, b) => a > b ? a : b);
    final position = Offset(avgX, maxY + 120.0); // 120px sotto il nodo più basso

    final positionedNode =
    (newNode as dynamic).copyWith(x: position.dx, y: position.dy) as FlowNode;

    // 4. Crea tutte le nuove connessioni (una per ogni nodo sorgente)
    final newEdges = sourceNodes
        .map((sourceNode) =>
        FlowchartEdge(from: sourceNode.id, to: positionedNode.id))
        .toList();

    // 5. Aggiorna il flowchart con il nuovo nodo e le nuove connessioni
    final newFlowchart = currentState.flowchart.copyWith(
      nodes: [...currentState.flowchart.nodes, positionedNode],
      edges: [...currentState.flowchart.edges, ...newEdges],
    );

    // 6. Emette lo stato finale, uscendo dalla modalità connettore
    emit(currentState.copyWith(
      flowchart: newFlowchart,
      isConnectorModeActive: false,
      clearConnectorSource: true,
      selectedConnectorNodeIds: {},
      selectedNodeId: positionedNode.id, // Seleziona il nodo appena creato
    ));
  }
}
