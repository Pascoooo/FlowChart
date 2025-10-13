import 'package:bloc/bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';
import '../../screens/user_dashboard/project_workspace/views/rules/flowchart_rule.dart' as rules;
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
    // 🆕 Gestione selezione ramo decisionale
    on<DebugBranchSelected>(_onDebugBranchSelected);
    // NEW: Memorizza il risultato valutato del Decision, senza navigare
    on<DebugDecisionEvaluated>(_onDebugDecisionEvaluated);
    on<AddGlobalVariable>(_onAddGlobalVariable);
    on<UpdateGlobalVariables>(_onUpdateGlobalVariables);
    on<UpdateFlowchart>(_onUpdateFlowchart);
    // =========================================================
    // ✨ REGISTRAZIONE DEI NUOVI EVENTI PER IL CONNETTORE ✨
    // =========================================================
    on<StartConnectorMode>(_onStartConnectorMode);
    on<ToggleConnectorNodeSelection>(_onToggleConnectorNodeSelection);
    on<ApplyConnectorAndCreateNode>(_onApplyConnectorAndCreateNode);
    on<CancelConnectorMode>(_onCancelConnectorMode);
    // Eventi per la selezione del corpo do-while
    on<StartDoWhileBodySelection>(_onStartDoWhileBodySelection);
    // ✨ NUOVO: tronca da un certo blocco
    on<ResetFromNode>(_onResetFromNode);
    on<StartResetFromNodeSelection>(_onStartResetFromNodeSelection); // ✨ NUOVO
    // 🔁 Ripristinati: chiusura ciclo e selezione inizio corpo do-while
    on<CloseLoop>(_onCloseLoop);
    on<SelectDoWhileBodyStart>(_onSelectDoWhileBodyStart);
    // 🆕 NUOVO: Gestione sottoprogrammi
    on<LoadProjectFlowcharts>(_onLoadProjectFlowcharts);
    on<DebugStepIntoSubprogram>(_onDebugStepIntoSubprogram);
    on<DebugReturnFromSubprogram>(_onDebugReturnFromSubprogram);
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;


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

  /// Aggiorna l'intero flowchart (variabili + nodi)
  void _onUpdateFlowchart(
      UpdateFlowchart event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    emit(currentState.copyWith(flowchart: event.flowchart));
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
      // Supporto per nuovo formato con clausole
      final clausesData = newData['clauses'] as List?;
      List<ConditionClause>? clauses;

      if (clausesData != null && clausesData.isNotEmpty) {
        clauses = clausesData
            .map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
            .toList();
      }

      return oldNode.copyWith(
        clauses: clauses,
        logicalJoin: newData['logicalJoin'] as String?,
      );
    }

    else if (oldNode is WhileNode) {
      final clausesData = newData['clauses'] as List?;
      List<ConditionClause>? clauses;

      if (clausesData != null && clausesData.isNotEmpty) {
        clauses = clausesData
            .map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
            .toList();
      }

      return oldNode.copyWith(
        clauses: clauses,
        logicalJoin: newData['logicalJoin'] as String?,
      );
    }

    else if (oldNode is DoWhileNode) {
      final clausesData = newData['clauses'] as List?;
      List<ConditionClause>? clauses;

      if (clausesData != null && clausesData.isNotEmpty) {
        clauses = clausesData
            .map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
            .toList();
      }

      return oldNode.copyWith(
        clauses: clauses,
        logicalJoin: newData['logicalJoin'] as String?,
      );
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
    // Prova a fare il parse in modo sicuro; se fallisce, non resettare lo stato
    final parsed = FlowchartLoaded.tryParse(event.jsonContent);
    if (parsed == null) {
      // parsing fallito: mantieni stato attuale per evitare reset del documento
      return;
    }

    // Evita ricarichi identici che azzerano la history (echo RTDB)
    if (state is FlowchartLoaded) {
      final currentJson = (state as FlowchartLoaded).toJson();
      if (currentJson == event.jsonContent) {
        return; // nessun cambiamento reale
      }
    }

    _history.clear();
    final loadedState = parsed;
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
    final validator = rules.FlowchartValidator();

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

    // ⚠️ NUOVO: Se è un do-while, avvia la modalità selezione corpo del ciclo
    if (newNode.kind == FlowNodeKind.doWhileLoop) {
      emit(command.execute(currentState).copyWith(
        selectedNodeId: newNode.id,
        // Attiva una modalità speciale per selezionare il nodo di inizio corpo
        isConnectorModeActive: true,
        connectorSourceNodeId: newNode.id,
        selectedConnectorNodeIds: <String>{},
        connectorPurpose: ConnectorPurpose.doWhileBody,
      ));
    } else {
      emit(command.execute(currentState).copyWith(selectedNodeId: newNode.id));
    }
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

    final outgoingFromNode = currentState.getOutgoingEdges(nodeToRemove.id);
    // Caso speciale: consenti rimozione del do-while se non ha il ramo 'false'
    bool allowDoWhileDeletion = false;
    if (nodeToRemove.kind == FlowNodeKind.doWhileLoop) {
      final hasFalse = outgoingFromNode.any((e) => e.port == 'false');
      if (!hasFalse) {
        allowDoWhileDeletion = true; // puoi eliminarlo anche se ha uscite (es. 'true')
      }
    }

    if (outgoingFromNode.isNotEmpty && !allowDoWhileDeletion) {
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
        final undoneState = command.undo(state as FlowchartLoaded);
        // Pulisci eventuale stato di selezione connettore/do-while rimasto attivo
        emit(undoneState.copyWith(
          isConnectorModeActive: false,
          clearConnectorSource: true,
          selectedConnectorNodeIds: <String>{},
        ));
      }
    }
  }

  void _onRedo(Redo event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      final current = state as FlowchartLoaded;
      final command = _history.redo();
      if (command != null) {
        final redoneState = command.execute(current);

        // Rileva eventuali do-while aggiunti da questo redo
        final beforeIds = current.flowchart.nodes.map((n) => n.id).toSet();
        final addedDoWhile = redoneState.flowchart.nodes.where(
          (n) => n.kind == FlowNodeKind.doWhileLoop && !beforeIds.contains(n.id),
        );

        if (addedDoWhile.isNotEmpty) {
          // Prendi il primo do-while aggiunto e verifica se ha già il ramo 'true'/'doWhileStart'
          final dw = addedDoWhile.first;
          final hasBodyEdge = redoneState.getOutgoingEdges(dw.id).any(
            (e) => e.port == 'true' || e.port == 'doWhileStart',
          );

          if (!hasBodyEdge) {
            // Riattiva la modalità di selezione del corpo come quando si crea il do-while
            emit(redoneState.copyWith(
              isConnectorModeActive: true,
              connectorSourceNodeId: dw.id,
              selectedConnectorNodeIds: <String>{},
              selectedNodeId: dw.id,
              connectorPurpose: ConnectorPurpose.doWhileBody,
            ));
            return;
          }
        }

        // Default: applica lo stato redone e pulisci eventuale selezione connettore residua
        emit(redoneState.copyWith(
          isConnectorModeActive: false,
          clearConnectorSource: true,
          selectedConnectorNodeIds: <String>{},
        ));
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
      // Priorità: prima cerca edge senza porta
      next = outgoing.firstWhere(
            (e) => e.port == null,
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );

      if (next.from.isEmpty && outgoing.isNotEmpty) {
        // Cerca prima tra gli edge non-loop
        final nonLoopEdges = outgoing.where((e) => e.port != 'loop').toList();
        if (nonLoopEdges.isNotEmpty) {
          next = nonLoopEdges.first;
        } else {
          // Se ci sono SOLO archi di loop, aggiungi il nodo target del loop e poi fermati
          final loopEdge = outgoing.firstWhere((e) => e.port == 'loop');
          path.add(loopEdge.to);
          break; // Ferma qui: il nodo del ciclo richiede rivalutazione
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

  // NEW handler: store decision result
  void _onDebugDecisionEvaluated(DebugDecisionEvaluated event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    final newMap = Map<String, bool>.from(s.decisionSelections);
    newMap[event.nodeId] = event.result;
    emit(s.copyWith(decisionSelections: newMap));
  }

  void _onDebugNext(DebugNextNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode || s.debugPath.isEmpty) return;

    final currentId = s.debugPath[s.debugIndex];
    final currentNode = s.getNodeById(currentId);
    if (currentNode == null) return;

    final outgoing = s.flowchart.edges.where((e) => e.from == currentId).toList();
    if (outgoing.isEmpty) {
      // Nessun next
      return;
    }

    FlowchartEdge? chosen;
    if (currentNode.kind == FlowNodeKind.decision ||
        currentNode.kind == FlowNodeKind.whileLoop ||
        currentNode.kind == FlowNodeKind.doWhileLoop) {
      // Usa il risultato valutato se presente
      if (s.decisionSelections.containsKey(currentId)) {
        final res = s.decisionSelections[currentId]!;
        // Mappa la scelta alla porta corretta in base al tipo
        // Preferisci sempre 'true'/'false'; mantieni compatibilità con 'doWhileStart' come 'true'.
        final String wantedPort = switch (currentNode.kind) {
          FlowNodeKind.decision => res ? 'true' : 'false',
          FlowNodeKind.whileLoop => res ? 'true' : 'false',
          FlowNodeKind.doWhileLoop => res ? 'true' : 'false',
          _ => 'true',
        };
        // Cerca la porta voluta
        chosen = outgoing.firstWhere(
          (e) => e.port == wantedPort,
          orElse: () => const FlowchartEdge(from: '', to: ''),
        );
        // Per compatibilità legacy, se do-while e non esiste 'true', prova 'doWhileStart'
        if (chosen.from.isEmpty && currentNode.kind == FlowNodeKind.doWhileLoop && res) {
          chosen = outgoing.firstWhere(
            (e) => e.port == 'doWhileStart',
            orElse: () => const FlowchartEdge(from: '', to: ''),
          );
        }
        // Fallback: edge senza porta
        if (chosen.from.isEmpty) {
          chosen = outgoing.firstWhere(
            (e) => e.port == null,
            orElse: () => const FlowchartEdge(from: '', to: ''),
          );
        }
      } else {
        // Nessuna selezione salvata: per i do-while entra nel corpo al primo passaggio (preferisci 'true'/'doWhileStart')
        if (currentNode.kind == FlowNodeKind.doWhileLoop) {
          chosen = outgoing.firstWhere(
            (e) => e.port == 'true',
            orElse: () => const FlowchartEdge(from: '', to: ''),
          );
          if (chosen.from.isEmpty) {
            // Compat: vecchia porta d'avvio
            chosen = outgoing.firstWhere(
              (e) => e.port == 'doWhileStart',
              orElse: () => const FlowchartEdge(from: '', to: ''),
            );
          }
          if (chosen.from.isEmpty) {
            // Ultimo tentativo: senza porta
            chosen = outgoing.firstWhere(
              (e) => e.port == null,
              orElse: () => const FlowchartEdge(from: '', to: ''),
            );
          }
        }
      }
    }

    // Se non è un Decision o non c'è selezione salvata, usa priorità di default
    if (chosen == null || chosen.from.isEmpty) {
      // Se esiste solo un arco di rientro ('loop'), segui quello per tornare alla condizione
      final loopEdges = outgoing.where((e) => e.port == 'loop').toList();
      final nonLoopEdges = outgoing.where((e) => e.port != 'loop').toList();

      if (nonLoopEdges.isEmpty && loopEdges.isNotEmpty) {
        chosen = loopEdges.first; // torna al nodo del ciclo per rivalutare
      } else {
        // Preferisci sempre archi non-loop
        if (nonLoopEdges.isEmpty) return; // Nessun next valido

        chosen = nonLoopEdges.firstWhere(
          (e) => e.port == null,
          orElse: () => const FlowchartEdge(from: '', to: ''),
        );
        if (chosen.from.isEmpty && nonLoopEdges.isNotEmpty) {
          chosen = nonLoopEdges.first;
        }
      }
    }

    if (chosen.from.isEmpty) return; // nessun candidato

    // Se abbiamo scelto un arco di rientro ('loop'), salta direttamente al nodo ciclo
    if (chosen.port == 'loop') {
      final newPath = <String>[];
      newPath.addAll(s.debugPath.take(s.debugIndex + 1));
      newPath.add(chosen.to);

      final nextIndex = s.debugIndex + 1;
      final newSelectedId = chosen.to;
      emit(s.copyWith(
        debugPath: newPath,
        debugIndex: nextIndex,
        selectedNodeId: newSelectedId,
        isDebugJustStarted: false,
      ));
      return; // Non costruire il tail: la condizione verrà rivalutata al passo successivo
    }

    // Ricostruisci tail da chosen.to, filtrando sempre gli archi di loop
    final tail = <String>[];
    final visited = <String>{};
    String? nid = chosen.to;
    while (nid != null && nid.isNotEmpty && !visited.contains(nid)) {
      tail.add(nid);
      visited.add(nid);

      final outs = s.flowchart.edges.where((e) => e.from == nid).toList();
      if (outs.isEmpty) break;

      // Filtra sempre gli archi di loop
      final nonLoopOuts = outs.where((e) => e.port != 'loop').toList();
      if (nonLoopOuts.isEmpty) break; // Solo archi di loop = stop

      FlowchartEdge? next = nonLoopOuts.firstWhere(
        (e) => e.port == null,
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );
      if (next.from.isEmpty && nonLoopOuts.isNotEmpty) {
        next = nonLoopOuts.first;
      }

      if (next.from.isEmpty) break;
      nid = next.to;
    }

    // Costruisci nuovo path
    final newPath = <String>[];
    newPath.addAll(s.debugPath.take(s.debugIndex + 1));
    newPath.addAll(tail);

    // Se nessun avanzamento
    if (newPath.length <= s.debugIndex + 1) {
      emit(s.copyWith(
        debugPath: newPath,
        selectedNodeId: s.selectedNodeId,
        isDebugJustStarted: false,
      ));
      return;
    }

    final nextIndex = s.debugIndex + 1;
    final newSelectedId = newPath[nextIndex];
    emit(s.copyWith(
      debugPath: newPath,
      debugIndex: nextIndex,
      selectedNodeId: newSelectedId,
      isDebugJustStarted: false,
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

  void _onDebugBranchSelected(DebugBranchSelected event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode || s.debugPath.isEmpty) return;

    final currentId = s.debugPath[s.debugIndex];

    // Trova l'edge in base al risultato
    final outgoing = s.flowchart.edges.where((e) => e.from == currentId).toList();
    FlowchartEdge? chosen;

    // Preferisci il ramo esplicito 'true'/'false'
    final wantedPort = event.result ? 'true' : 'false';
    chosen = outgoing.firstWhere(
      (e) => e.port == wantedPort,
      orElse: () => const FlowchartEdge(from: '', to: ''),
    );

    // In assenza, usa un edge senza porta (se presente)
    if (chosen.from.isEmpty) {
      chosen = outgoing.firstWhere(
        (e) => e.port == null,
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );
    }

    if (chosen.from.isEmpty) {
      // Nessun edge adatto: non possiamo avanzare
      return;
    }

    // Ricostruisci il tail path a partire dal nodo scelto
    final tail = <String>[];
    final visited = <String>{};
    String? nid = chosen.to;
    while (nid != null && nid.isNotEmpty && !visited.contains(nid)) {
      tail.add(nid);
      visited.add(nid);

      final outs = s.flowchart.edges.where((e) => e.from == nid).toList();
      if (outs.isEmpty) break;

      FlowchartEdge? next;
      // priorità: senza porta -> 'true' -> 'false'
      next = outs.firstWhere((e) => e.port == null,
          orElse: () => const FlowchartEdge(from: '', to: ''));
      if (next.from.isEmpty) {
        next = outs.firstWhere((e) => e.port == 'true',
            orElse: () => const FlowchartEdge(from: '', to: ''));
        if (next.from.isEmpty) {
          next = outs.firstWhere((e) => e.port == 'false',
              orElse: () => const FlowchartEdge(from: '', to: ''));
        }
      }
      if (next.from.isEmpty) break;
      nid = next.to;
    }

    // Nuovo path = prefisso fino al nodo corrente + tail
    final newPath = <String>[];
    newPath.addAll(s.debugPath.take(s.debugIndex + 1));
    newPath.addAll(tail);

    if (newPath.length <= s.debugIndex + 1) {
      // Nessun avanzamento possibile
      emit(s.copyWith(
        debugPath: newPath,
        selectedNodeId: s.selectedNodeId,
        isDebugJustStarted: false,
      ));
      return;
    }

    final nextIndex = s.debugIndex + 1;
    final newSelectedId = newPath[nextIndex];

    emit(s.copyWith(
      debugPath: newPath,
      debugIndex: nextIndex,
      selectedNodeId: newSelectedId,
      isDebugJustStarted: false,
    ));
  }

  // 🆕 NUOVO: Return from subprogram - Ritorna dal sottoprogramma al chiamante
  void _onDebugReturnFromSubprogram(
      DebugReturnFromSubprogram event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode || s.callStack.isEmpty) return;

    final currentFrame = s.callStack.current;
    if (currentFrame == null) return;

    // 1. Pop dello stack per tornare al chiamante
    final newCallStack = s.callStack.pop();

    // 2. Recupera il flowchart del chiamante
    Flowchart callerFlowchart;
    if (newCallStack.isEmpty) {
      // Torniamo al main: cerca il flowchart main nei projectFlowcharts
      callerFlowchart = s.projectFlowcharts.values.firstWhere(
        (f) => f.type == FlowchartType.main,
        orElse: () => s.flowchart, // fallback: mantieni il corrente
      );
    } else {
      // Torniamo a un sottoprogramma intermedio
      final parentFrame = newCallStack.current!;
      callerFlowchart = s.projectFlowcharts[parentFrame.flowchartId] ?? s.flowchart;
    }

    // 3. Trova il nodo ProcessNode chiamante nel flowchart del chiamante
    final callerNodeId = currentFrame.callerNodeId;
    if (callerNodeId == null) {
      debugPrint('⚠️ callerNodeId è null, impossibile tornare al chiamante');
      return;
    }

    // 4. Ricostruisci il path di debug partendo dal nodo successivo alla chiamata
    final outgoing = callerFlowchart.edges.where((e) => e.from == callerNodeId).toList();

    final List<String> resumePath = [];
    final visited = <String>{};

    // Aggiungi il nodo chiamante al path
    resumePath.add(callerNodeId);

    // Se ci sono nodi successivi, costruisci il tail
    if (outgoing.isNotEmpty) {
      FlowchartEdge? next = outgoing.firstWhere(
        (e) => e.port == null,
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );

      if (next.from.isEmpty && outgoing.isNotEmpty) {
        next = outgoing.first;
      }

      if (next.from.isNotEmpty) {
        String? nid = next.to;
        while (nid != null && nid.isNotEmpty && !visited.contains(nid)) {
          resumePath.add(nid);
          visited.add(nid);

          final outs = callerFlowchart.edges.where((e) => e.from == nid).toList();
          if (outs.isEmpty) break;

          final nonLoopOuts = outs.where((e) => e.port != 'loop').toList();
          if (nonLoopOuts.isEmpty) break;

          FlowchartEdge? nextEdge = nonLoopOuts.firstWhere(
            (e) => e.port == null,
            orElse: () => const FlowchartEdge(from: '', to: ''),
          );

          if (nextEdge.from.isEmpty && nonLoopOuts.isNotEmpty) {
            nextEdge = nonLoopOuts.first;
          }

          if (nextEdge.from.isEmpty) break;
          nid = nextEdge.to;
        }
      }
    }

    // 5. Trova l'indice del nodo chiamante + 1 per posizionarci sul nodo successivo
    final resumeIndex = resumePath.length > 1 ? 1 : 0;
    final resumeNodeId = resumePath.length > resumeIndex ? resumePath[resumeIndex] : resumePath.first;

    // 6. Emetti il nuovo stato tornando al chiamante
    emit(s.copyWith(
      flowchart: callerFlowchart,
      debugPath: resumePath,
      debugIndex: resumeIndex,
      selectedNodeId: resumeNodeId,
      callStack: newCallStack,
      isDebugJustStarted: false,
    ));

    debugPrint('✅ Ritorno dal sottoprogramma: valore = ${event.returnValue}');
  }

  void _onStartConnectorMode(
      StartConnectorMode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final source = currentState.getNodeById(event.fromNodeId);
    if (source == null) return;
    // Guard: End node cannot be a connector source
    if (source.kind == FlowNodeKind.end) {
      return; // ignore activation if starting from End
    }

    // Pre-seleziona automaticamente il nodo di origine
    emit(currentState.copyWith(
      isConnectorModeActive: true,
      connectorSourceNodeId: event.fromNodeId,
      selectedConnectorNodeIds: {event.fromNodeId}, // Pre-seleziona il nodo di origine
      connectorPurpose: ConnectorPurpose.normal,
      clearSelection: true,
    ));
  }

  void _onToggleConnectorNodeSelection(
      ToggleConnectorNodeSelection event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    if (!currentState.isConnectorModeActive) return;

    final node = currentState.getNodeById(event.nodeId);
    if (node == null) return;
    // Guard: End node cannot be selected as a source in connector mode
    if (node.kind == FlowNodeKind.end) {
      return; // ignore selection of End nodes
    }

    // Se siamo in selezione corpo do-while: permetti UNA sola selezione
    final source = currentState.connectorSourceNodeId != null
        ? currentState.getNodeById(currentState.connectorSourceNodeId!)
        : null;
    final isDoWhileBodySelection =
        currentState.connectorPurpose == ConnectorPurpose.doWhileBody ||
            source?.kind == FlowNodeKind.doWhileLoop;

    final isResetSelection =
        currentState.connectorPurpose == ConnectorPurpose.resetFromNode;

    if (isDoWhileBodySelection || isResetSelection) {
      // toggle singolo: se già selezionato -> deseleziona, altrimenti seleziona solo questo
      final isAlready =
          currentState.selectedConnectorNodeIds.contains(event.nodeId);
      emit(currentState.copyWith(
        selectedConnectorNodeIds:
            isAlready ? <String>{} : <String>{event.nodeId},
      ))
      ;
      return;
    }

    // Modalità connettore normale (multi-selezione)
    final newSelectedIds =
        Set<String>.from(currentState.selectedConnectorNodeIds);
    if (newSelectedIds.contains(event.nodeId)) {
      newSelectedIds.remove(event.nodeId);
    } else {
      newSelectedIds.add(event.nodeId);
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
      connectorPurpose: null,
    ));
  }

  void _onApplyConnectorAndCreateNode(
      ApplyConnectorAndCreateNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    if (!currentState.isConnectorModeActive ||
        currentState.connectorSourceNodeId == null) return;

    // 1. Raccoglie tutti gli ID dei nodi sorgente
    final rawSourceNodeIds = {
      currentState.connectorSourceNodeId!,
      ...currentState.selectedConnectorNodeIds
    };

    // Filtra eventuali nodi 'Fine' (non ammessi come sorgente)
    final sourceNodes = rawSourceNodeIds
        .map((id) => currentState.getNodeById(id))
        .whereType<FlowNode>()
        .where((n) => n.kind != FlowNodeKind.end)
        .toList();

    if (sourceNodes.isEmpty) {
      // Sicurezza: se non ci sono nodi validi, annulla l'operazione
      add(const CancelConnectorMode());
      return;
    }

    // Caso speciale: se il target richiesto è un nodo Fine, non crearne uno nuovo.
    if (event.kind == FlowNodeKind.end) {
      // Chiama l'evento dedicato per collegare al Fine esistente per ogni sorgente
      for (final src in sourceNodes) {
        add(LinkToExistingEnd(fromNodeId: src.id));
      }

      // Esci dalla modalità connettore
      emit(currentState.copyWith(
        isConnectorModeActive: false,
        clearConnectorSource: true,
        selectedConnectorNodeIds: {},
        connectorPurpose: null,
      ));
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
    final updatedFlowchart = currentState.flowchart.copyWith(
      nodes: [...currentState.flowchart.nodes, positionedNode],
      edges: [...currentState.flowchart.edges, ...newEdges],
    );

    // 6. Registra comando per undo/redo e applica lo stato
    final command = UpdateFlowchartCommand(
      oldFlowchart: currentState.flowchart,
      newFlowchart: updatedFlowchart,
      description:
          'Connettore: crea ${event.kind.name} da ${sourceNodes.length} sorgenti',
    );
    _history.executeCommand(command);
    final afterExecute = command.execute(currentState);

    // 7. Emette lo stato finale, uscendo dalla modalità connettore e selezionando il nuovo nodo
    emit(afterExecute.copyWith(
      isConnectorModeActive: false,
      clearConnectorSource: true,
      selectedNodeId: positionedNode.id,
      connectorPurpose: null,
    ));
  }

  void _onStartDoWhileBodySelection(
      StartDoWhileBodySelection event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final doWhileNode = currentState.getNodeById(event.doWhileNodeId);
    if (doWhileNode == null || doWhileNode.kind != FlowNodeKind.doWhileLoop) {
      return;
    }

    emit(currentState.copyWith(
      isConnectorModeActive: true,
      connectorSourceNodeId: event.doWhileNodeId,
      selectedConnectorNodeIds: {}, // reset selezione
      connectorPurpose: ConnectorPurpose.doWhileBody,
      clearSelection: true,
    ));
  }

  void _onCloseLoop(CloseLoop event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    final from = s.getNodeById(event.fromNodeId);
    final loop = s.getNodeById(event.loopNodeId);
    if (from == null || loop == null) return;

    // Il nodo di ciclo dev'essere While o DoWhile
    if (loop.kind != FlowNodeKind.whileLoop && loop.kind != FlowNodeKind.doWhileLoop) {
      emit(const FlowchartActionFailure(
        title: 'Chiusura ciclo non valida',
        message: 'Il nodo di destinazione non è un ciclo.',
      ));
      emit(s);
      return;
    }

    // Verifica che il nodo di partenza sia all'interno del ciclo indicato
    final parentLoopId = s.getParentLoopNodeId(from.id);
    if (parentLoopId != loop.id) {
      emit(const FlowchartActionFailure(
        title: 'Nodo fuori ciclo',
        message: 'Puoi chiudere il ciclo solo da un nodo appartenente a quel ciclo.',
      ));
      emit(s);
      return;
    }

    // Evita duplicati della chiusura
    final alreadyExists = s.flowchart.edges.any(
      (e) => e.from == from.id && e.to == loop.id && e.port == 'loop',
    );
    if (alreadyExists) {
      return; // niente da fare
    }

    final newEdge = FlowchartEdge(from: from.id, to: loop.id, port: 'loop');

    // Valida secondo le regole
    final validator = rules.FlowchartValidator();
    final validation = validator.validate(s, newEdge);
    if (!validation.isValid) {
      emit(FlowchartActionFailure(title: 'Connessione non permessa', message: validation.errorMessage ?? ''));
      emit(s);
      return;
    }

    final updated = s.flowchart.copyWith(edges: [...s.flowchart.edges, newEdge]);
    final cmd = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updated,
      description: 'Chiudi ciclo',
    );
    _history.executeCommand(cmd);

    emit(cmd.execute(s));
  }

  void _onSelectDoWhileBodyStart(
      SelectDoWhileBodyStart event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    final loop = s.getNodeById(event.doWhileNodeId);
    final bodyStart = s.getNodeById(event.bodyStartNodeId);
    if (loop == null || bodyStart == null) return;

    if (loop.kind != FlowNodeKind.doWhileLoop) {
      emit(const FlowchartActionFailure(
        title: 'Selezione non valida',
        message: 'Il nodo selezionato non è un ciclo post-condizionale.',
      ));
      emit(s);
      return;
    }

    // Regola di validità: il bodyStart deve essere un antenato del ciclo e non può essere Start / il ciclo stesso
    if (!s.isValidDoWhileBodyStart(loop.id, bodyStart.id)) {
      emit(const FlowchartActionFailure(
        title: 'Nodo non valido',
        message: 'Seleziona un nodo valido come inizio del corpo del ciclo.',
      ));
      emit(s);
      return;
    }

    // Rimuovi eventuali archi esistenti che definiscono già l'inizio del corpo ('true' o legacy 'doWhileStart')
    final filteredEdges = s.flowchart.edges.where((e) {
      if (e.from != loop.id) return true;
      // elimina definizioni precedenti di inizio corpo
      return e.port != 'true' && e.port != 'doWhileStart';
    }).toList();

    // Aggiungi il nuovo arco di avvio corpo con porta standard 'true'
    final startEdge = FlowchartEdge(from: loop.id, to: bodyStart.id, port: 'true');

    // Valida la nuova connessione
    final validator = rules.FlowchartValidator();
    final validation = validator.validate(s, startEdge);
    if (!validation.isValid) {
      emit(FlowchartActionFailure(title: 'Connessione non permessa', message: validation.errorMessage ?? ''));
      emit(s);
      return;
    }

    final updated = s.flowchart.copyWith(edges: [...filteredEdges, startEdge]);
    final cmd = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updated,
      description: 'Imposta inizio corpo do-while',
    );
    _history.executeCommand(cmd);

    emit(cmd.execute(s).copyWith(
      // Esci dalla modalità selezione corpo
      isConnectorModeActive: false,
      clearConnectorSource: true,
      selectedConnectorNodeIds: {},
      connectorPurpose: null,
      selectedNodeId: loop.id,
    ));
  }

  void _onResetFromNode(ResetFromNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    final target = s.getNodeById(event.nodeId);
    if (target == null) return;

    // 1) Rimuovi tutte le uscite dal nodo target (diventa foglia)
    final remainingEdges = s.flowchart.edges.where((e) => e.from != target.id).toList();

    // 2) Se target è un do-while: ricorda il bodyStart (se presente) per NON cancellarlo
    String? preservedBodyStartId;
    if (target.kind == FlowNodeKind.doWhileLoop) {
      // trova 'true' o legacy 'doWhileStart'
      final bodyEdge = s.flowchart.edges.firstWhere(
        (e) => e.from == target.id && (e.port == 'true' || e.port == 'doWhileStart'),
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );
      if (bodyEdge.from.isNotEmpty) {
        preservedBodyStartId = bodyEdge.to;
      }
    }

    // 3) Calcola i nodi raggiungibili da Start con il nuovo insieme di archi
    final startNode = s.flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.start, orElse: () => s.flowchart.nodes.first);
    final visited = <String>{};
    final queue = <String>[startNode.id];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (!visited.add(cur)) continue;
      for (final e in remainingEdges) {
        if (e.from == cur) queue.add(e.to);
      }
    }

    // 4) Costruisci il nuovo insieme di nodi mantenendo quelli raggiungibili e l'eventuale bodyStart preservato
    final newNodes = s.flowchart.nodes.where((n) => visited.contains(n.id) || (preservedBodyStartId != null && n.id == preservedBodyStartId)).toList();

    // 5) Filtra anche gli archi: tieni solo quelli interni al nuovo insieme
    final allowedIds = newNodes.map((n) => n.id).toSet();
    final newEdges = remainingEdges.where((e) => allowedIds.contains(e.from) && allowedIds.contains(e.to)).toList();

    final newFlowchart = s.flowchart.copyWith(nodes: newNodes, edges: newEdges);
    final cmd = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: newFlowchart,
      description: 'Resetta da blocco',
    );
    _history.executeCommand(cmd);
    emit(cmd.execute(s).copyWith(
      selectedNodeId: target.id,
      isConnectorModeActive: false,
      clearConnectorSource: true,
      selectedConnectorNodeIds: {},
      connectorPurpose: null,
    ));
  }

  void _onStartResetFromNodeSelection(
      StartResetFromNodeSelection event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    emit(s.copyWith(
      isConnectorModeActive: true,
      selectedConnectorNodeIds: {},
      clearConnectorSource: true,
      connectorPurpose: ConnectorPurpose.resetFromNode,
      clearSelection: true,
    ));
  }

  // 🆕 NUOVO: Carica tutti i flowchart del progetto per risolvere le chiamate
  void _onLoadProjectFlowcharts(
      LoadProjectFlowcharts event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    emit(s.copyWith(projectFlowcharts: event.flowcharts));
  }

  // 🆕 NUOVO: Step into - Entra nel sottoprogramma chiamato
  void _onDebugStepIntoSubprogram(
      DebugStepIntoSubprogram event, Emitter<FlowchartState> emit) async {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode) return;

    final callNode = event.callNode;

    // 1. Risolvi il flowchart chiamato
    final calleeFlowchart = s.projectFlowcharts[callNode.flowchartToCall];
    if (calleeFlowchart == null) {
      debugPrint('⚠️ Sottoprogramma "${callNode.flowchartToCall}" non trovato');
      return;
    }

    // 2. Valuta gli argomenti passati dal chiamante
    try {
      final callerVars = await _getDebugVariables(s.flowchart.flowchartId);
      final argValues = <dynamic>[];

      for (final argExpr in callNode.arguments) {
        final result = _evaluateExpression(argExpr, callerVars);
        if (result == null) {
          debugPrint('⚠️ Errore nella valutazione dell\'argomento: $argExpr');
          return;
        }
        argValues.add(result);
      }

      // 3. Mappa gli argomenti ai parametri INPUT del sottoprogramma
      final inputParams = calleeFlowchart.variables
          .where((v) => v.scope == VariableScope.input)
          .toList();

      final paramMap = <String, dynamic>{};
      for (int i = 0; i < inputParams.length && i < argValues.length; i++) {
        paramMap[inputParams[i].name] = argValues[i];
      }

      // 4. Salva i parametri nelle variabili di debug del sottoprogramma
      if (paramMap.isNotEmpty) {
        await _updateDebugVariables(calleeFlowchart.flowchartId, paramMap);
      }

      // 5. Crea un nuovo frame dello stack
      final frame = CallStackFrame(
        flowchartId: calleeFlowchart.flowchartId,
        flowchartName: calleeFlowchart.name,
        callerNodeId: callNode.id,
        parameters: paramMap,
        returnType: calleeFlowchart.signature.returnType,
      );

      // 6. Aggiorna lo stack di chiamate
      final newCallStack = s.callStack.push(frame);

      // 7. Trova il nodo di start del sottoprogramma
      final headerNode = calleeFlowchart.nodes.firstWhere(
        (n) => n.kind == FlowNodeKind.functionHeader,
        orElse: () => calleeFlowchart.nodes.first,
      );

      // 8. Costruisci il path di debug per il sottoprogramma
      final List<String> subPath = [];
      final visited = <String>{};
      String? currentId = headerNode.id;

      while (currentId != null && currentId.isNotEmpty && !visited.contains(currentId)) {
        subPath.add(currentId);
        visited.add(currentId);

        final outgoing = calleeFlowchart.edges.where((e) => e.from == currentId).toList();
        if (outgoing.isEmpty) break;

        FlowchartEdge? next = outgoing.firstWhere(
          (e) => e.port == null,
          orElse: () => const FlowchartEdge(from: '', to: ''),
        );

        if (next.from.isEmpty && outgoing.isNotEmpty) {
          final nonLoopEdges = outgoing.where((e) => e.port != 'loop').toList();
          if (nonLoopEdges.isNotEmpty) {
            next = nonLoopEdges.first;
          }
        }

        if (next.from.isEmpty) break;
        currentId = next.to;
      }

      if (subPath.isEmpty) {
        debugPrint('⚠️ Impossibile costruire il path di debug per il sottoprogramma');
        return;
      }

      // 9. Emetti il nuovo stato con il flowchart del sottoprogramma caricato
      emit(s.copyWith(
        flowchart: calleeFlowchart,
        debugPath: subPath,
        debugIndex: 0,
        selectedNodeId: subPath.first,
        callStack: newCallStack,
        isDebugJustStarted: false,
      ));
    } catch (e) {
      debugPrint('⚠️ Errore durante lo step-into: $e');
    }
  }

  // Helper: valuta un'espressione con le variabili correnti
  dynamic _evaluateExpression(String expr, Map<String, dynamic> vars) {
    try {
      // Sostituisci i placeholder {var} con i valori effettivi
      String evaluatedExpr = expr;
      final pattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
      final matches = pattern.allMatches(expr);

      for (final match in matches) {
        final varName = match.group(1)!;
        if (vars.containsKey(varName)) {
          evaluatedExpr = evaluatedExpr.replaceAll('{$varName}', vars[varName].toString());
        }
      }

      // Se l'espressione è solo una variabile, restituisci il valore direttamente
      if (vars.containsKey(evaluatedExpr)) {
        return vars[evaluatedExpr];
      }

      // Prova a parsare come numero
      final numValue = num.tryParse(evaluatedExpr);
      if (numValue != null) return numValue;

      // Prova a parsare come booleano
      if (evaluatedExpr.toLowerCase() == 'true') return true;
      if (evaluatedExpr.toLowerCase() == 'false') return false;

      // Altrimenti restituisci come stringa
      return evaluatedExpr;
    } catch (e) {
      debugPrint('Errore valutazione espressione: $e');
      return null;
    }
  }

  // Helper: ottieni le variabili di debug (stub - da implementare con il tuo repository)
  Future<Map<String, dynamic>> _getDebugVariables(String flowchartId) async {
    // Questo metodo dovrebbe chiamare il tuo repository per ottenere le variabili
    // Per ora, restituiamo una mappa vuota come placeholder
    return {};
  }

  // Helper: aggiorna le variabili di debug (stub - da implementare con il tuo repository)
  Future<void> _updateDebugVariables(String flowchartId, Map<String, dynamic> vars) async {
    // Questo metodo dovrebbe chiamare il tuo repository per aggiornare le variabili
    debugPrint('Aggiornamento variabili per $flowchartId: $vars');
  }
}
