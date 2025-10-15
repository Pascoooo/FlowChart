import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';
import '../../screens/user_dashboard/project_workspace/views/rules/flowchart_rule.dart' as rules;
import 'commands/command_history.dart';
import 'commands/flowchart_command.dart';
import 'flowchart_event.dart';
import 'flowchart_shape_factory.dart';
import 'flowchart_state.dart';
import 'placement_engine.dart';

class _FlowchartCacheEntry {
  final Flowchart flowchart;
  final CommandHistory history;

  _FlowchartCacheEntry({required this.flowchart, required this.history});
}

class FlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> {
  final ProjectRepo _projectRepository;
  final Map<String, _FlowchartCacheEntry> _cache = {};
  String? _activeFileId;
  CommandHistory _history = CommandHistory();

  FlowchartBloc({required ProjectRepo projectRepository})
      : _projectRepository = projectRepository,
        super(FlowchartInitial()) {
    on<LoadFlowchart>(_onLoadFlowchart);
    on<ClearFlowchartCache>(_onClearFlowchartCache);
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
    on<DebugBranchSelected>(_onDebugBranchSelected);
    on<DebugDecisionEvaluated>(_onDebugDecisionEvaluated);
    on<AddGlobalVariable>(_onAddGlobalVariable);
    on<UpdateGlobalVariables>(_onUpdateGlobalVariables);
    on<UpdateFlowchart>(_onUpdateFlowchart);
    on<StartConnectorMode>(_onStartConnectorMode);
    on<ToggleConnectorNodeSelection>(_onToggleConnectorNodeSelection);
    on<ApplyConnectorAndCreateNode>(_onApplyConnectorAndCreateNode);
    on<CancelConnectorMode>(_onCancelConnectorMode);
    on<StartDoWhileBodySelection>(_onStartDoWhileBodySelection);
    on<ResetFromNode>(_onResetFromNode);
    on<StartResetFromNodeSelection>(_onStartResetFromNodeSelection);
    on<CloseLoop>(_onCloseLoop);
    on<SelectDoWhileBodyStart>(_onSelectDoWhileBodyStart);
    on<LoadProjectFlowcharts>(_onLoadProjectFlowcharts);
    on<DebugStepIntoSubprogram>(_onDebugStepIntoSubprogram);
    on<DebugReturnFromSubprogram>(_onDebugReturnFromSubprogram);
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  Future<Map<String, dynamic>> _getDebugVariables(String flowchartId) async {
    return _projectRepository.getDebugVariables(projectId: flowchartId);
  }

  Future<void> _updateDebugVariables(
      String flowchartId, Map<String, dynamic> vars) async {
    await _projectRepository.updateDebugVariables(
        projectId: flowchartId, variables: vars);
  }

  void _onClearFlowchartCache(
      ClearFlowchartCache event, Emitter<FlowchartState> emit) {
    _cache.clear();
    _history.clear();
    _activeFileId = null;
    emit(FlowchartInitial());
  }

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    final currentState = state is FlowchartLoaded ? state as FlowchartLoaded : null;

    if (_activeFileId != null && currentState != null) {
      _cache[_activeFileId!] = _FlowchartCacheEntry(
        flowchart: currentState.flowchart,
        history: _history,
      );
    }

    _activeFileId = event.fileId;
    Flowchart flowchartToLoad;

    if (_cache.containsKey(event.fileId)) {
      final cachedEntry = _cache[event.fileId]!;
      flowchartToLoad = cachedEntry.flowchart;
      _history = cachedEntry.history;
    } else {
      try {
        flowchartToLoad = Flowchart.fromEntity(
            FlowchartEntity.fromDocument(jsonDecode(event.jsonContent)));
      } catch (e) {
        debugPrint('Errore nel parsing del flowchart: $e');
        return;
      }
      _history = CommandHistory();
    }

    final flowchartWithName = flowchartToLoad.copyWith(name: event.fileName);

    emit(FlowchartLoaded(
      flowchart: flowchartWithName,
      projectFlowcharts: currentState?.projectFlowcharts ?? {},
    ));
  }

  void _onAddGlobalVariable(
      AddGlobalVariable event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    if (currentState.flowchart.variables
        .any((v) => v.name == event.variable.name)) {
      return;
    }

    final newVariables = [...currentState.flowchart.variables, event.variable];
    final newFlowchart =
    currentState.flowchart.copyWith(variables: newVariables);

    final command = UpdateFlowchartCommand(
        oldFlowchart: currentState.flowchart,
        newFlowchart: newFlowchart,
        description: 'Aggiungi variabile globale');
    _history.executeCommand(command);
    emit(command.execute(currentState));
  }

  void _onUpdateGlobalVariables(
      UpdateGlobalVariables event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final newFlowchart =
    currentState.flowchart.copyWith(variables: event.variables);
    final command = UpdateFlowchartCommand(
        oldFlowchart: currentState.flowchart,
        newFlowchart: newFlowchart,
        description: 'Aggiorna variabili globali');
    _history.executeCommand(command);
    emit(command.execute(currentState));
  }

  void _onUpdateFlowchart(
      UpdateFlowchart event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    emit(currentState.copyWith(flowchart: event.flowchart));
  }

  // ✨ MODIFICA 1: Salva una "fotografia" del flowchart chiamante nello stack
  void _onDebugStepIntoSubprogram(
      DebugStepIntoSubprogram event, Emitter<FlowchartState> emit) async {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode) return;

    final callNode = event.callNode;
    final flowchartIdentifier = callNode.flowchartToCall;

    Flowchart? calleeFlowchart = s.projectFlowcharts[flowchartIdentifier];

    if (calleeFlowchart == null) {
      debugPrint('⚠️ Sottoprogramma "$flowchartIdentifier" non trovato.');
      return;
    }

    try {
      final callerVars = await _getDebugVariables(s.flowchart.flowchartId);
      final argValues = <dynamic>[];

      for (final argExpr in callNode.arguments) {
        final result = _evaluateExpression(argExpr, callerVars);
        argValues.add(result);
      }

      final inputParams = calleeFlowchart.variables
          .where((v) => v.scope == VariableScope.input)
          .toList();

      final paramMap = <String, dynamic>{};
      for (int i = 0; i < inputParams.length && i < argValues.length; i++) {
        paramMap[inputParams[i].name] = argValues[i];
      }

      if (paramMap.isNotEmpty) {
        await _updateDebugVariables(calleeFlowchart.flowchartId, paramMap);
      }

      final frame = CallStackFrame(
        flowchartId: calleeFlowchart.flowchartId,
        flowchartName: calleeFlowchart.name,
        callerNodeId: callNode.id,
        parameters: paramMap,
        returnType: calleeFlowchart.signature.returnType,
        debugPath: s.debugPath,
        // ✨ SALVA LA FOTOGRAFIA DEL CHIAMANTE
        callerFlowchart: s.flowchart,
      );

      final newCallStack = s.callStack.push(frame);

      late FlowNode startNode;
      try {
        startNode = calleeFlowchart.nodes.firstWhere(
              (n) => n.kind == FlowNodeKind.functionHeader,
        );
      } catch (_) {
        startNode = calleeFlowchart.nodes.first;
      }

      final List<String> subPath = [];
      String? currentId = startNode.id;
      final visited = <String>{startNode.id}; // Evita cicli infiniti

      while (currentId != null && currentId.isNotEmpty) {
        subPath.add(currentId);
        final outgoing = calleeFlowchart.edges.where((e) => e.from == currentId).toList();
        if (outgoing.isEmpty) break;

        FlowchartEdge? next = outgoing.firstWhere(
              (e) => e.port == null,
          orElse: () => const FlowchartEdge(from: '', to: ''),
        );
        if (next.from.isEmpty && outgoing.isNotEmpty) {
          next = outgoing.firstWhere((e) => e.port != 'loop', orElse: () => outgoing.first);
        }
        if (next.from.isEmpty) break;

        currentId = next.to;
        if (visited.contains(currentId)) break; // Esce se rileva un ciclo
        visited.add(currentId);
      }

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

  // ✨ MODIFICA 2: Usa la "fotografia" per tornare allo stato corretto
  void _onDebugReturnFromSubprogram(
      DebugReturnFromSubprogram event, Emitter<FlowchartState> emit) async {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode || s.callStack.isEmpty) return;

    final leavingFrame = s.callStack.current;
    if (leavingFrame == null) return;

    final newCallStack = s.callStack.pop();
    final callerNodeId = leavingFrame.callerNodeId;

    if (callerNodeId == null) {
      add(const DebugExit());
      return;
    }

    // ✨ RIPRISTINA LA FOTOGRAFIA, NON CARICARE DALL'ARCHIVIO!
    final Flowchart callerFlowchart = leavingFrame.callerFlowchart;

    try {
      final callerNode = callerFlowchart.nodes.firstWhere((n) => n.id == callerNodeId) as ProcessNode;
      if (callerNode.resultTarget != null &&
          callerNode.resultTarget!.isNotEmpty &&
          event.returnValue != null) {
        final update = {callerNode.resultTarget!: event.returnValue};
        await _updateDebugVariables(callerFlowchart.flowchartId, update);
        debugPrint('✅ Assegnato valore "${event.returnValue}" a "${callerNode.resultTarget}"');
      }
    } catch (e) {
      debugPrint('⚠️ Errore assegnazione valore di ritorno: $e');
    }

    final callerPath = leavingFrame.debugPath;
    final callerNodeIndex = callerPath.indexOf(callerNodeId);

    if (callerNodeIndex == -1) {
      add(const DebugExit());
      return;
    }

    final nextIndex = callerNodeIndex + 1;
    if (nextIndex >= callerPath.length) {
      add(const DebugExit());
      return;
    }

    final nextNodeId = callerPath[nextIndex];

    emit(s.copyWith(
      flowchart: callerFlowchart, // ✨ Usa il flowchart ripristinato
      debugPath: callerPath,
      debugIndex: nextIndex,
      selectedNodeId: nextNodeId,
      callStack: newCallStack,
      isDebugJustStarted: false,
    ));
  }

  // ✨ MODIFICA 3: Gestisci l'uscita dal debug da un sottoprogramma
  void _onDebugExit(DebugExit event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // Se stiamo uscendo da un sottoprogramma, dobbiamo tornare al main
    if (!s.callStack.isEmpty) {
      final mainFrame = s.callStack.frames.first;

      // Se il primo frame non è main, cerca il main
      final mainFlowchart = mainFrame.callerFlowchart.type == FlowchartType.main
          ? mainFrame.callerFlowchart
          : s.projectFlowcharts.values.firstWhere((fc) => fc.type == FlowchartType.main);

      emit(FlowchartLoaded(
        flowchart: mainFlowchart,
        projectFlowcharts: s.projectFlowcharts,
      ));
      return;
    }

    // Se siamo già nel main, esci normalmente
    emit(s.copyWith(
      isDebugMode: false,
      debugPath: const [],
      debugIndex: 0,
      isDebugJustStarted: false,
    ));
  }

  // (Il resto del codice rimane invariato, lo includo per completezza)

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

    if (newNode.kind == FlowNodeKind.doWhileLoop) {
      emit(command.execute(currentState).copyWith(
        selectedNodeId: newNode.id,
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
    bool allowDoWhileDeletion = false;
    if (nodeToRemove.kind == FlowNodeKind.doWhileLoop) {
      final hasFalse = outgoingFromNode.any((e) => e.port == 'false');
      if (!hasFalse) {
        allowDoWhileDeletion = true;
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

        final beforeIds = current.flowchart.nodes.map((n) => n.id).toSet();
        final addedDoWhile = redoneState.flowchart.nodes.where(
              (n) => n.kind == FlowNodeKind.doWhileLoop && !beforeIds.contains(n.id),
        );

        if (addedDoWhile.isNotEmpty) {
          final dw = addedDoWhile.first;
          final hasBodyEdge = redoneState.getOutgoingEdges(dw.id).any(
                (e) => e.port == 'true' || e.port == 'doWhileStart',
          );

          if (!hasBodyEdge) {
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

    if (currentState.flowchart.isFunction) {
      final headerNode = currentState.flowchart.nodes.firstWhere(
            (n) => n.kind == FlowNodeKind.functionHeader,
        orElse: () => throw Exception('FunctionHeaderNode non trovato in un sottoprogramma'),
      );

      final parameterNames = currentState.flowchart.signature.parameters.map((p) => p.name).toSet();
      final variablesToKeep = currentState.flowchart.variables
          .where((v) => parameterNames.contains(v.name))
          .toList();

      final newFlowchart = currentState.flowchart.copyWith(
        nodes: [headerNode],
        edges: <FlowchartEdge>[],
        variables: variablesToKeep,
      );

      emit(FlowchartLoaded(
        flowchart: newFlowchart,
        selectedNodeId: headerNode.id,
        projectFlowcharts: currentState.projectFlowcharts,
      ));
    } else {
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
        projectFlowcharts: currentState.projectFlowcharts,
      ));
    }
  }

  void _onResetCanvasPreserveVariables(
      ResetCanvasPreserveVariables event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    _history.clear();

    if (currentState.flowchart.isFunction) {
      final headerNode = currentState.flowchart.nodes.firstWhere(
            (n) => n.kind == FlowNodeKind.functionHeader,
        orElse: () => throw Exception('FunctionHeaderNode non trovato in un sottoprogramma'),
      );

      final newFlowchart = currentState.flowchart.copyWith(
        nodes: [headerNode],
        edges: <FlowchartEdge>[],
      );

      emit(FlowchartLoaded(
        flowchart: newFlowchart,
        selectedNodeId: headerNode.id,
        projectFlowcharts: currentState.projectFlowcharts,
      ));
    } else {
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
        projectFlowcharts: currentState.projectFlowcharts,
      ));
    }
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
    String? currentId = start.id;
    final visited = <String>{start.id};

    while (currentId != null && currentId.isNotEmpty) {
      path.add(currentId);
      final outgoing =
      s.flowchart.edges.where((e) => e.from == currentId).toList();
      if (outgoing.isEmpty) break;

      FlowchartEdge? next;
      next = outgoing.firstWhere(
            (e) => e.port == null,
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );

      if (next.from.isEmpty && outgoing.isNotEmpty) {
        next = outgoing.firstWhere((e) => e.port != 'loop', orElse: () => outgoing.first);
      }

      if (next.from.isEmpty) break;

      currentId = next.to;
      if (visited.contains(currentId)) break;
      visited.add(currentId);
    }

    if (path.isEmpty) return;

    emit(s.copyWith(
      isDebugMode: true,
      debugPath: path,
      debugIndex: 0,
      selectedNodeId: path.first,
      isDebugJustStarted: true,
    ));
  }

  void _onDebugNext(DebugNextNode event, Emitter<FlowchartState> emit) async {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode || s.debugPath.isEmpty || s.debugIndex >= s.debugPath.length) return;

    final currentId = s.debugPath[s.debugIndex];
    final currentNode = s.getNodeById(currentId);
    if (currentNode == null) return;

    if (currentNode is ProcessNode && currentNode.flowchartToCall.isNotEmpty) {
      add(DebugStepIntoSubprogram(currentNode));
      return;
    }

    if ((currentNode.kind == FlowNodeKind.end || currentNode.kind == FlowNodeKind.returnNode) && !s.callStack.isEmpty) {
      _handleReturnFromSubprogram(emit, s);
      return;
    }

    final nextIndex = s.debugIndex + 1;
    if (nextIndex >= s.debugPath.length) {
      return;
    }

    emit(s.copyWith(
      debugIndex: nextIndex,
      selectedNodeId: s.debugPath[nextIndex],
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
    emit(s.copyWith(
      debugIndex: prevIndex,
      selectedNodeId: newNodeId,
      isDebugJustStarted: false,
    ));
  }

  void _onDebugBranchSelected(DebugBranchSelected event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode || s.debugPath.isEmpty) return;

    final currentId = s.debugPath[s.debugIndex];

    // ... La logica qui è complessa e soggetta a errori,
    // per ora la semplifichiamo affidandoci al path precalcolato.
    // L'implementazione corretta richiederebbe un motore di esecuzione dinamico.
    add(const DebugNextNode());
  }

  void _onDebugDecisionEvaluated(DebugDecisionEvaluated event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    final newMap = Map<String, bool>.from(s.decisionSelections);
    newMap[event.nodeId] = event.result;
    emit(s.copyWith(decisionSelections: newMap));
  }

  Future<void> _handleReturnFromSubprogram(Emitter<FlowchartState> emit, FlowchartLoaded s) async {
    final currentFrame = s.callStack.current;
    if (currentFrame == null) return;
    try {
      final sessionVars = await _getDebugVariables(s.flowchart.flowchartId);

      final returnVar = s.flowchart.variables
          .where((v) => v.scope == VariableScope.output)
          .firstOrNull;

      dynamic returnValue;
      if (returnVar != null && sessionVars.containsKey(returnVar.name)) {
        returnValue = sessionVars[returnVar.name];
      }

      add(DebugReturnFromSubprogram(returnValue: returnValue));
    } catch (e) {
      debugPrint('⚠️ Errore nel recupero del valore di ritorno: $e');
      add(const DebugReturnFromSubprogram());
    }
  }

  void _onStartConnectorMode(
      StartConnectorMode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final source = currentState.getNodeById(event.fromNodeId);
    if (source == null || source.kind == FlowNodeKind.end) {
      return;
    }

    emit(currentState.copyWith(
      isConnectorModeActive: true,
      connectorSourceNodeId: event.fromNodeId,
      selectedConnectorNodeIds: {event.fromNodeId},
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
    if (node == null || node.kind == FlowNodeKind.end) {
      return;
    }

    final source = currentState.connectorSourceNodeId != null
        ? currentState.getNodeById(currentState.connectorSourceNodeId!)
        : null;
    final isDoWhileBodySelection =
        currentState.connectorPurpose == ConnectorPurpose.doWhileBody ||
            source?.kind == FlowNodeKind.doWhileLoop;

    final isResetSelection =
        currentState.connectorPurpose == ConnectorPurpose.resetFromNode;

    if (isDoWhileBodySelection || isResetSelection) {
      final isAlready =
      currentState.selectedConnectorNodeIds.contains(event.nodeId);
      emit(currentState.copyWith(
        selectedConnectorNodeIds:
        isAlready ? <String>{} : <String>{event.nodeId},
      ));
      return;
    }

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

    final rawSourceNodeIds = {
      currentState.connectorSourceNodeId!,
      ...currentState.selectedConnectorNodeIds
    };

    final sourceNodes = rawSourceNodeIds
        .map((id) => currentState.getNodeById(id))
        .whereType<FlowNode>()
        .where((n) => n.kind != FlowNodeKind.end)
        .toList();

    if (sourceNodes.isEmpty) {
      add(const CancelConnectorMode());
      return;
    }

    if (event.kind == FlowNodeKind.end) {
      for (final src in sourceNodes) {
        add(LinkToExistingEnd(fromNodeId: src.id));
      }

      emit(currentState.copyWith(
        isConnectorModeActive: false,
        clearConnectorSource: true,
        selectedConnectorNodeIds: {},
        connectorPurpose: null,
      ));
      return;
    }

    final newNode = FlowNodeFactory.createNode(
      event.kind,
      Offset.zero,
      allVariables: currentState.flowchart.variables,
      initialData: event.initialData,
    );

    final avgX =
        sourceNodes.map((n) => n.x).reduce((a, b) => a + b) / sourceNodes.length;
    final maxY = sourceNodes
        .map((n) => n.y + n.height)
        .reduce((a, b) => a > b ? a : b);
    final position = Offset(avgX, maxY + 120.0);

    final positionedNode =
    (newNode as dynamic).copyWith(x: position.dx, y: position.dy) as FlowNode;

    final newEdges = sourceNodes
        .map((sourceNode) =>
        FlowchartEdge(from: sourceNode.id, to: positionedNode.id))
        .toList();

    final updatedFlowchart = currentState.flowchart.copyWith(
      nodes: [...currentState.flowchart.nodes, positionedNode],
      edges: [...currentState.flowchart.edges, ...newEdges],
    );

    final command = UpdateFlowchartCommand(
      oldFlowchart: currentState.flowchart,
      newFlowchart: updatedFlowchart,
      description:
      'Connettore: crea ${event.kind.name} da ${sourceNodes.length} sorgenti',
    );
    _history.executeCommand(command);
    final afterExecute = command.execute(currentState);

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
      selectedConnectorNodeIds: {},
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

    if (loop.kind != FlowNodeKind.whileLoop && loop.kind != FlowNodeKind.doWhileLoop) {
      emit(const FlowchartActionFailure(
        title: 'Chiusura ciclo non valida',
        message: 'Il nodo di destinazione non è un ciclo.',
      ));
      emit(s);
      return;
    }

    final parentLoopId = s.getParentLoopNodeId(from.id);
    if (parentLoopId != loop.id) {
      emit(const FlowchartActionFailure(
        title: 'Nodo fuori ciclo',
        message: 'Puoi chiudere il ciclo solo da un nodo appartenente a quel ciclo.',
      ));
      emit(s);
      return;
    }

    final alreadyExists = s.flowchart.edges.any(
          (e) => e.from == from.id && e.to == loop.id && e.port == 'loop',
    );
    if (alreadyExists) {
      return;
    }

    final newEdge = FlowchartEdge(from: from.id, to: loop.id, port: 'loop');

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

    if (!s.isValidDoWhileBodyStart(loop.id, bodyStart.id)) {
      emit(const FlowchartActionFailure(
        title: 'Nodo non valido',
        message: 'Seleziona un nodo valido come inizio del corpo del ciclo.',
      ));
      emit(s);
      return;
    }

    final filteredEdges = s.flowchart.edges.where((e) {
      if (e.from != loop.id) return true;
      return e.port != 'true' && e.port != 'doWhileStart';
    }).toList();

    final startEdge = FlowchartEdge(from: loop.id, to: bodyStart.id, port: 'true');

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

    final remainingEdges = s.flowchart.edges.where((e) => e.from != target.id).toList();

    String? preservedBodyStartId;
    if (target.kind == FlowNodeKind.doWhileLoop) {
      final bodyEdge = s.flowchart.edges.firstWhere(
            (e) => e.from == target.id && (e.port == 'true' || e.port == 'doWhileStart'),
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );
      if (bodyEdge.from.isNotEmpty) {
        preservedBodyStartId = bodyEdge.to;
      }
    }

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

    final newNodes = s.flowchart.nodes.where((n) => visited.contains(n.id) || (preservedBodyStartId != null && n.id == preservedBodyStartId)).toList();

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

  void _onLoadProjectFlowcharts(
      LoadProjectFlowcharts event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      final s = state as FlowchartLoaded;
      emit(s.copyWith(projectFlowcharts: event.flowcharts));
      return;
    }

    final empty = FlowchartLoaded.empty();
    emit(empty.copyWith(projectFlowcharts: event.flowcharts));
  }

  dynamic _evaluateExpression(String expr, Map<String, dynamic> vars) {
    try {
      String evaluatedExpr = expr;
      final pattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
      final matches = pattern.allMatches(expr);

      for (final match in matches) {
        final varName = match.group(1)!;
        if (vars.containsKey(varName)) {
          evaluatedExpr = evaluatedExpr.replaceAll('{$varName}', vars[varName].toString());
        }
      }

      if (vars.containsKey(evaluatedExpr)) {
        return vars[evaluatedExpr];
      }

      final numValue = num.tryParse(evaluatedExpr);
      if (numValue != null) return numValue;

      if (evaluatedExpr.toLowerCase() == 'true') return true;
      if (evaluatedExpr.toLowerCase() == 'false') return false;

      return evaluatedExpr;
    } catch (e) {
      debugPrint('Errore valutazione espressione: $e');
      return null;
    }
  }
}