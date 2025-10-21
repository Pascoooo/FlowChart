import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
  // 🆕 Stato UI persistito per file
  final String? selectedNodeId;
  final bool isConnectorModeActive;
  final String? connectorSourceNodeId;
  final Set<String> selectedConnectorNodeIds;
  final ConnectorPurpose? connectorPurpose;
  final Map<String, Flowchart> projectFlowcharts;
  final bool isDebugMode;

  _FlowchartCacheEntry({
    required this.flowchart,
    required this.history,
    this.selectedNodeId,
    this.isConnectorModeActive = false,
    this.connectorSourceNodeId,
    this.selectedConnectorNodeIds = const {},
    this.connectorPurpose,
    this.projectFlowcharts = const {},
    this.isDebugMode = false,
  });
}

class FlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> {
  final Map<String, _FlowchartCacheEntry> _cache = {};
  String? _activeFileId;
  CommandHistory _history = CommandHistory();

  // ✅ FIX #3: Getter pubblico per il file attivo nel FlowchartBloc
  String? get activeFileId => _activeFileId;

  FlowchartBloc() :
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
    on<SetDebugMode>(_onSetDebugMode); // 🟠 FIX #7: Nuovo handler
    on<StartLoopClosureMode>(_onStartLoopClosureMode); // 🆕 NUOVO
    on<ApplyLoopClosure>(_onApplyLoopClosure); // 🆕 NUOVO
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void _onClearFlowchartCache(
      ClearFlowchartCache event, Emitter<FlowchartState> emit) {
    // ✅ FIX #5: logging e salvataggio ultimo file prima della pulizia
    if (_activeFileId != null && state is FlowchartLoaded) {
      final currentState = state as FlowchartLoaded;
      debugPrint('🗃️ Salvataggio ultimo flowchart in cache prima della clear: fileId=$_activeFileId');
      _cache[_activeFileId!] = _FlowchartCacheEntry(
        flowchart: currentState.flowchart,
        history: _history,
        selectedNodeId: currentState.selectedNodeId,
        isConnectorModeActive: currentState.isConnectorModeActive,
        connectorSourceNodeId: currentState.connectorSourceNodeId,
        selectedConnectorNodeIds: currentState.selectedConnectorNodeIds,
        connectorPurpose: currentState.connectorPurpose,
        projectFlowcharts: currentState.projectFlowcharts,
        isDebugMode: currentState.isDebugMode,
      );
    }

    debugPrint('🗑️ Pulizia cache FlowchartBloc e azzeramento history');
    _cache.clear();
    _history.clear();
    _activeFileId = null;
    emit(FlowchartInitial());
  }

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    final currentState = state is FlowchartLoaded ? state as FlowchartLoaded : null;

    // ✅ FIX #1A: salva in cache il flowchart precedente SOLO se si cambia file
    if (_activeFileId != null && currentState != null && _activeFileId != event.fileId) {
      debugPrint('💾 Cache prev flowchart: fileId=$_activeFileId');
      _cache[_activeFileId!] = _FlowchartCacheEntry(
        flowchart: currentState.flowchart,
        history: _history,
        selectedNodeId: currentState.selectedNodeId,
        isConnectorModeActive: currentState.isConnectorModeActive,
        connectorSourceNodeId: currentState.connectorSourceNodeId,
        selectedConnectorNodeIds: currentState.selectedConnectorNodeIds,
        connectorPurpose: currentState.connectorPurpose,
        projectFlowcharts: currentState.projectFlowcharts,
        isDebugMode: currentState.isDebugMode,
      );
    }

    // ✅ FIX #1B: aggiorna l'ID attivo prima di procedere
    final previousFileId = _activeFileId;
    _activeFileId = event.fileId;
    debugPrint('📂 FlowchartBloc cambio file: "$previousFileId" → "${_activeFileId}"');

    if (_cache.containsKey(event.fileId)) {
      // 🆕 Carica stato completo da cache
      final cachedEntry = _cache[event.fileId]!;
      // Aggiorna solo il nome, mantieni il resto dello stato
      final flowchartWithName = cachedEntry.flowchart.copyWith(name: event.fileName);
      _history = cachedEntry.history;
      emit(FlowchartLoaded(
        flowchart: flowchartWithName,
        selectedNodeId: cachedEntry.selectedNodeId,
        isConnectorModeActive: cachedEntry.isConnectorModeActive,
        connectorSourceNodeId: cachedEntry.connectorSourceNodeId,
        selectedConnectorNodeIds: cachedEntry.selectedConnectorNodeIds,
        connectorPurpose: cachedEntry.connectorPurpose,
        projectFlowcharts: cachedEntry.projectFlowcharts,
        isDebugMode: cachedEntry.isDebugMode,
      ));
      return;
    }

    Flowchart flowchartToLoad;

    if (_cache.containsKey(event.fileId)) {
      final cachedEntry = _cache[event.fileId]!;
      flowchartToLoad = cachedEntry.flowchart;
      _history = cachedEntry.history;
      debugPrint('✅ Caricato flowchart da cache per fileId=${event.fileId}');
    } else {
      try {
        flowchartToLoad = Flowchart.fromEntity(
            FlowchartEntity.fromDocument(jsonDecode(event.jsonContent)));
        _history = CommandHistory();
        debugPrint('✅ Caricato flowchart da JSON per fileId=${event.fileId}');
      } catch (e) {
        debugPrint('❌ Errore parsing flowchart: $e');
        return;
      }
    }

    final flowchartWithName = flowchartToLoad.copyWith(name: event.fileName);

    // 🔒 Costruisci stato provvisorio per ispezione regole post-condizionale
    final baseLoaded = FlowchartLoaded(
      flowchart: flowchartWithName,
      projectFlowcharts: currentState?.projectFlowcharts ?? {},
      isDebugMode: (currentState?.isDebugMode ?? false),
    );

    // 🧭 Se esistono do-while senza corpo e ORA ci sono candidati validi, forza la selezione
    final unresolved = baseLoaded.unresolvedDoWhileIds();
    String? targetDoWhileId;
    for (final id in unresolved) {
      if (baseLoaded.hasEligibleDoWhileBodyCandidates(id)) {
        targetDoWhileId = id;
        break;
      }
    }

    if (targetDoWhileId != null) {
      debugPrint('🧩 Do-while senza corpo rilevato ($targetDoWhileId). Attivo selezione corpo.');
      emit(baseLoaded.copyWith(
        isConnectorModeActive: true,
        connectorSourceNodeId: targetDoWhileId,
        selectedConnectorNodeIds: <String>{},
        connectorPurpose: ConnectorPurpose.doWhileBody,
        selectedNodeId: targetDoWhileId,
      ));
      return;
    }

    emit(FlowchartLoaded(
      flowchart: flowchartWithName,
      projectFlowcharts: currentState?.projectFlowcharts ?? {},
      isDebugMode: (currentState?.isDebugMode ?? false),
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

  // ============================================================================
  // CANVAS EDITING - Invariato (metodi esistenti)
  // ============================================================================
  void _onAddNode(AddNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // 🟠 FIX MAGGIORE #7: Blocca editing durante debug
    if (s.isDebugMode) {
      emit(const FlowchartActionFailure(
        title: 'Debug in corso',
        message: 'Non puoi modificare il flowchart durante il debug.',
      ));
      emit(s);
      return;
    }

    final fromNode = s.getNodeById(event.fromNodeId);
    if (fromNode == null) return;

    // 🚫 Requisito: non consentire do-while se c'è solo il nodo Start (nessun blocco dopo l'inizio)
    if (event.kind == FlowNodeKind.doWhileLoop) {
      // Se stai tentando dal nodo Start, verifica che esista almeno un nodo raggiungibile dopo Start
      if (fromNode.kind == FlowNodeKind.start) {
        // BFS in avanti a partire da Start seguendo gli edge esistenti
        final start = fromNode;
        final visited = <String>{};
        final queue = <String>[start.id];
        bool hasNonStartAfter = false;
        while (queue.isNotEmpty) {
          final cur = queue.removeAt(0);
          if (!visited.add(cur)) continue;
          for (final e in s.flowchart.edges) {
            if (e.from == cur) {
              final next = s.getNodeById(e.to);
              if (next == null) continue;
              if (next.kind != FlowNodeKind.start) {
                hasNonStartAfter = true;
                break;
              }
              queue.add(next.id);
            }
          }
          if (hasNonStartAfter) break;
        }
        if (!hasNonStartAfter) {
          emit(const FlowchartActionFailure(
            title: 'Operazione non valida',
            message: 'Aggiungi prima almeno un blocco dopo "Inizio" prima di creare un ciclo do-while.',
          ));
          emit(s);
          return;
        }
      }
    }

    // Determina la dimensione del nuovo nodo in base al tipo
    final newNodeSize = _getNodeSize(event.kind);

    // Usa PlacementEngine per trovare la posizione ottimale
    final position = PlacementEngine.findOptimalPosition(
      fromNode: fromNode,
      newNodeSize: newNodeSize,
      existingNodes: s.flowchart.nodes,
      canvasConstraints: event.canvasConstraints,
      fromPort: event.fromPort,
    );

    if (position == null) {
      emit(const FlowchartActionFailure(
        title: 'Spazio insufficiente',
        message: 'Non c\'è spazio disponibile per aggiungere il nodo.',
      ));
      emit(s);
      return;
    }

    // Crea il nuovo nodo usando FlowNodeFactory
    final newNode = FlowNodeFactory.createNode(
      event.kind,
      position,
      allVariables: s.flowchart.variables,
      initialData: event.initialData,
    );

    // Crea l'edge di connessione
    final newEdge = FlowchartEdge(
      from: event.fromNodeId,
      to: newNode.id,
      port: event.fromPort,
    );

    // Valida la connessione
    final validator = rules.FlowchartValidator();
    final validation = validator.validate(s, newEdge);
    if (!validation.isValid) {
      emit(FlowchartActionFailure(
        title: 'Connessione non permessa',
        message: validation.errorMessage ?? '',
      ));
      emit(s);
      return;
    }

    final updatedFlowchart = s.flowchart.copyWith(
      nodes: [...s.flowchart.nodes, newNode],
      edges: [...s.flowchart.edges, newEdge],
    );

    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updatedFlowchart,
      description: 'Aggiungi nodo ${event.kind.name}',
    );
    _history.executeCommand(command);

    // ✅ FIX: Se è un DoWhileNode, attiva la modalità selezione del blocco di inizio
    if (event.kind == FlowNodeKind.doWhileLoop) {
      emit(command.execute(s).copyWith(
        isConnectorModeActive: true,
        connectorSourceNodeId: newNode.id,
        selectedConnectorNodeIds: {},
        connectorPurpose: ConnectorPurpose.doWhileBody,
        selectedNodeId: newNode.id,
      ));
      return;
    }

    // 🧭 Se abbiamo do-while pendenti senza corpo e ora ci sono candidati validi, forza selezione
    final tmpLoaded = s.copyWith(flowchart: updatedFlowchart);
    final unresolved = tmpLoaded.unresolvedDoWhileIds();
    String? targetDoWhileId;
    for (final id in unresolved) {
      if (tmpLoaded.hasEligibleDoWhileBodyCandidates(id)) {
        targetDoWhileId = id;
        break;
      }
    }

    if (targetDoWhileId != null) {
      debugPrint('🧩 Do-while senza corpo ora risolvibile ($targetDoWhileId). Attivo selezione corpo.');
      emit(command.execute(s).copyWith(
        isConnectorModeActive: true,
        connectorSourceNodeId: targetDoWhileId,
        selectedConnectorNodeIds: {},
        connectorPurpose: ConnectorPurpose.doWhileBody,
        selectedNodeId: targetDoWhileId,
      ));
      return;
    }

    // ℹ️ Se il nuovo nodo è dentro un while che non ha ancora la chiusura, logga un suggerimento
    final afterAdd = s.copyWith(flowchart: updatedFlowchart);
    final parentLoopId = afterAdd.getParentLoopNodeId(newNode.id);
    if (parentLoopId != null) {
      final loop = afterAdd.getNodeById(parentLoopId);
      if (loop != null && loop.kind == FlowNodeKind.whileLoop) {
        if (!afterAdd.whileHasLoopClosure(loop.id)) {
          debugPrint('💡 Suggerimento: hai inserito un blocco dentro un while (${loop.id}). Aggiungi la chiusura del ciclo (fine ciclo).');
        }
      }
    }

    emit(command.execute(s));
  }

  Size _getNodeSize(FlowNodeKind kind) {
    return switch (kind) {
      FlowNodeKind.start || FlowNodeKind.end => const Size(90, 90),
      FlowNodeKind.decision || FlowNodeKind.whileLoop || FlowNodeKind.doWhileLoop => const Size(120, 80),
      FlowNodeKind.functionHeader => const Size(250, 100),
      FlowNodeKind.returnNode => const Size(140, 70),
      _ => const Size(150, 60),
    };
  }

  void _onRemoveNode(RemoveNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // 🟠 FIX MAGGIORE #7: Blocca editing durante debug
    if (s.isDebugMode) {
      emit(const FlowchartActionFailure(
        title: 'Debug in corso',
        message: 'Non puoi modificare il flowchart durante il debug.',
      ));
      emit(s);
      return;
    }

    final nodeToRemove = s.getNodeById(event.nodeId);
    if (nodeToRemove == null) return;

    // Rimuovi anche gli edge collegati
    final updatedEdges = s.flowchart.edges.where((e) => e.from != event.nodeId && e.to != event.nodeId).toList();
    final updatedNodes = s.flowchart.nodes.where((n) => n.id != event.nodeId).toList();

    final updatedFlowchart = s.flowchart.copyWith(nodes: updatedNodes, edges: updatedEdges);

    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updatedFlowchart,
      description: 'Rimuovi nodo ${nodeToRemove.text}',
    );
    _history.executeCommand(command);

    // 🧭 Se un do-while è rimasto senza corpo ma adesso esistono candidati, forza selezione
    final tmpLoaded = s.copyWith(flowchart: updatedFlowchart);
    final unresolved = tmpLoaded.unresolvedDoWhileIds();
    String? targetDoWhileId;
    for (final id in unresolved) {
      if (tmpLoaded.hasEligibleDoWhileBodyCandidates(id)) {
        targetDoWhileId = id;
        break;
      }
    }

    if (targetDoWhileId != null) {
      debugPrint('🧩 Do-while senza corpo dopo rimozione ($targetDoWhileId). Attivo selezione corpo.');
      emit(command.execute(s).copyWith(
        isConnectorModeActive: true,
        connectorSourceNodeId: targetDoWhileId,
        selectedConnectorNodeIds: {},
        connectorPurpose: ConnectorPurpose.doWhileBody,
        selectedNodeId: targetDoWhileId,
      ));
      return;
    }

    emit(command.execute(s));
  }

  void _onUpdateNodePosition(UpdateNodePosition event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // 🟠 FIX: Blocca editing durante debug
    if (s.isDebugMode) {
      emit(const FlowchartActionFailure(
        title: 'Debug in corso',
        message: 'Non puoi modificare il flowchart durante il debug.',
      ));
      emit(s);
      return;
    }

    final updatedNodes = s.flowchart.nodes.map((node) {
      if (node.id != event.nodeId) return node;
      // Ogni tipo di nodo ha il proprio copyWith con x e y
      return switch (node.kind) {
        FlowNodeKind.start => (node as StartNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.end => (node as EndNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.process => (node as ProcessNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.decision => (node as DecisionNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.input => (node as InputNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.output => (node as OutputNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.assignment => (node as AssignmentNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.whileLoop => (node as WhileNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.doWhileLoop => (node as DoWhileNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.functionHeader => (node as FunctionHeaderNode).copyWith(x: event.newX, y: event.newY),
        FlowNodeKind.returnNode => (node as ReturnNode).copyWith(x: event.newX, y: event.newY),
        _ => node,
      };
    }).toList();

    final updatedFlowchart = s.flowchart.copyWith(nodes: updatedNodes);

    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updatedFlowchart,
      description: 'Sposta nodo ${event.nodeId}',
    );
    _history.executeCommand(command);

    emit(command.execute(s));
  }

  void _onUpdateNodeContent(UpdateNodeContent event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    final updatedNodes = s.flowchart.nodes.map((node) {
      if (node.id != event.nodeId) return node;

      // Ogni tipo di nodo ha parametri diversi per copyWith
      // Usa i dati in event.newData per aggiornare il nodo appropriatamente
      return switch (node.kind) {
        FlowNodeKind.process => (node as ProcessNode).copyWith(
          text: event.newData['text'] as String?,
          flowchartToCall: event.newData['flowchartToCall'] as String?,
          arguments: (event.newData['arguments'] as List?)?.cast<String>(),
          resultTarget: event.newData['resultTarget'] as String?,
        ),
        FlowNodeKind.assignment => (node as AssignmentNode).copyWith(
          text: event.newData['text'] as String?,
          assignments: (event.newData['assignments'] as List?)
              ?.map((a) => Assignment.fromMap(a as Map<String, dynamic>))
              .toList(),
        ),
        FlowNodeKind.input => (node as InputNode).copyWith(
          text: event.newData['text'] as String?,
          targetVariables: (event.newData['targetVariables'] as List?)?.cast<String>(),
        ),
        FlowNodeKind.output => (node as OutputNode).copyWith(
          text: event.newData['text'] as String?,
          template: event.newData['template'] as String?,
          variables: (event.newData['variables'] as List<VariableDeclaration>?) ?? node.variables,
        ),
        FlowNodeKind.decision => (node as DecisionNode).copyWith(
          text: event.newData['text'] as String?,
          clauses: (event.newData['clauses'] as List?)
              ?.map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
              .toList(),
          logicalJoin: event.newData['logicalJoin'] as String?,
        ),
        FlowNodeKind.whileLoop => (node as WhileNode).copyWith(
          text: event.newData['text'] as String?,
          clauses: (event.newData['clauses'] as List?)
              ?.map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
              .toList(),
          logicalJoin: event.newData['logicalJoin'] as String?,
        ),
        FlowNodeKind.doWhileLoop => (node as DoWhileNode).copyWith(
          text: event.newData['text'] as String?,
          clauses: (event.newData['clauses'] as List?)
              ?.map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
              .toList(),
          logicalJoin: event.newData['logicalJoin'] as String?,
        ),
        FlowNodeKind.returnNode => (node as ReturnNode).copyWith(
          text: event.newData['text'] as String?,
          returnExpression: event.newData['returnExpression'] as String?,
        ),
        _ => node, // Altri tipi non hanno contenuto modificabile
      };
    }).toList();

    final updatedFlowchart = s.flowchart.copyWith(nodes: updatedNodes);

    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updatedFlowchart,
      description: 'Aggiorna contenuto nodo ${event.nodeId}',
    );
    _history.executeCommand(command);

    emit(command.execute(s));
  }

  void _onSelectNode(SelectNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    emit(s.copyWith(selectedNodeId: event.nodeId));
  }

  void _onDeselectNode(DeselectNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    emit(s.copyWith(selectedNodeId: null));
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

  void _onLinkToExistingEnd(LinkToExistingEnd event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    final fromNode = s.getNodeById(event.fromNodeId);
    if (fromNode == null) return;

    // Cerca un nodo "End" esistente nel flowchart
    final endNode = s.flowchart.nodes.firstWhere(
          (n) => n.kind == FlowNodeKind.end,
      orElse: () => s.flowchart.nodes.first, // fallback
    );

    if (endNode.kind != FlowNodeKind.end) {
      emit(const FlowchartActionFailure(
        title: 'Nodo Fine non trovato',
        message: 'Non esiste un nodo Fine da collegare.',
      ));
      emit(s);
      return;
    }

    final newEdge = FlowchartEdge(from: fromNode.id, to: endNode.id, port: event.fromPort);

    final validator = rules.FlowchartValidator();
    final validation = validator.validate(s, newEdge);
    if (!validation.isValid) {
      emit(FlowchartActionFailure(title: 'Connessione non permessa', message: validation.errorMessage ?? ''));
      emit(s);
      return;
    }

    final updatedFlowchart = s.flowchart.copyWith(edges: [...s.flowchart.edges, newEdge]);
    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updatedFlowchart,
      description: 'Collega a nodo Fine esistente',
    );
    _history.executeCommand(command);

    emit(command.execute(s));
  }

  void _onResetCanvasAndVariables(ResetCanvasAndVariables event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    final initialFlowchart = s.flowchart.copyWith(
      nodes: [],
      edges: [],
      variables: s.flowchart.variables,
    );

    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: initialFlowchart,
      description: 'Resetta canvas e variabili',
    );
    _history.executeCommand(command);

    emit(command.execute(s));
  }

  void _onResetCanvasPreserveVariables(ResetCanvasPreserveVariables event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // Preserva il nodo di Inizio (per main) o l'Header (per funzioni)
    FlowNode? preservedNode;
    if (s.flowchart.type == FlowchartType.main) {
      try {
        preservedNode = s.flowchart.nodes.firstWhere(
              (n) => n.kind == FlowNodeKind.start,
        );
      } catch (_) {
        // Se non esiste, crea un nuovo Start in posizione di default
        preservedNode = FlowNodeFactory.createNode(
          FlowNodeKind.start,
          const Offset(1030.0, 50.0),
          allVariables: s.flowchart.variables,
        );
      }
    } else {
      // Funzione: preserva il FunctionHeader
      try {
        preservedNode = s.flowchart.nodes.firstWhere(
              (n) => n.kind == FlowNodeKind.functionHeader,
        );
      } catch (_) {
        // Header mancante: ricrealo a partire dalla signature del flowchart
        final params = s.flowchart.signature.parameters;
        const uuid = Uuid();
        preservedNode = FunctionHeaderNode(
          id: 'header-${uuid.v4()}',
          x: 1030.0,
          y: 50.0,
          width: 250.0,
          height: 100.0,
          functionName: s.flowchart.name,
          returnType: s.flowchart.signature.returnType,
          parameters: params,
        );
      }
    }

    final initialFlowchart = s.flowchart.copyWith(
      nodes: [preservedNode],
      edges: const <FlowchartEdge>[],
      // Mantieni le variabili esistenti
      variables: s.flowchart.variables,
      // Signature invariata (copyWith non la modifica se non passata)
    );

    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: initialFlowchart,
      description: 'Resetta canvas (mantieni variabili e nodo di intestazione)',
    );
    _history.executeCommand(command);

    emit(command.execute(s));
  }

  void _onClearHistory(ClearHistory event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    _history.clear();

    emit(s);
  }

  void _onStartConnectorMode(StartConnectorMode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // Se è già attiva un'altra modalità speciale, blocca
    if (s.isConnectorModeActive && s.connectorPurpose != ConnectorPurpose.normal) {
      emit(const FlowchartActionFailure(
        title: 'Operazione non disponibile',
        message: 'Completa o annulla la modalità attiva prima di usare il connettore.',
      ));
      emit(s);
      return;
    }

    final source = s.getNodeById(event.fromNodeId);
    if (source == null) return;

    // Impedisci l'avvio della connector mode dal nodo Fine
    if (source.kind == FlowNodeKind.end) {
      emit(const FlowchartActionFailure(
        title: 'Nodo non valido',
        message: 'Il nodo Fine non può essere usato come sorgente per il connettore.',
      ));
      emit(s); // ripristina stato
      return;
    }

    emit(s.copyWith(
      isConnectorModeActive: true,
      connectorSourceNodeId: event.fromNodeId,
      selectedConnectorNodeIds: {},
      selectedNodeId: event.fromNodeId,
      connectorPurpose: ConnectorPurpose.normal, // separa esplicitamente dalla reset mode
      // clearSelection: false
    ));
  }

  void _onToggleConnectorNodeSelection(ToggleConnectorNodeSelection event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    final purpose = s.connectorPurpose;

    // Selezione singola per reset/do-while body, multipla per connettore normale
    if (purpose == ConnectorPurpose.resetFromNode || purpose == ConnectorPurpose.doWhileBody) {
      // Se è già selezionato, deseleziona; altrimenti imposta come unico selezionato
      Set<String> newSelectedIds;
      if (s.selectedConnectorNodeIds.contains(event.nodeId)) {
        newSelectedIds = <String>{};
      } else {
        newSelectedIds = {event.nodeId};
      }
      emit(s.copyWith(selectedConnectorNodeIds: newSelectedIds));
      return;
    }

    final newSelectedIds = Set<String>.from(s.selectedConnectorNodeIds);
    if (newSelectedIds.contains(event.nodeId)) {
      newSelectedIds.remove(event.nodeId);
    } else {
      newSelectedIds.add(event.nodeId);
    }

    emit(s.copyWith(selectedConnectorNodeIds: newSelectedIds));
  }

  void _onApplyConnectorAndCreateNode(ApplyConnectorAndCreateNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // Il nodo sorgente è quello salvato nello stato quando si attiva la modalità connettore
    if (s.connectorSourceNodeId == null) return;

    final sourceNode = s.getNodeById(s.connectorSourceNodeId!);
    if (sourceNode == null) return;

    // 🚫 Requisito: non consentire do-while se c'è solo il nodo Start (nessun blocco dopo l'inizio)
    if (event.kind == FlowNodeKind.doWhileLoop && sourceNode.kind == FlowNodeKind.start) {
      final start = sourceNode;
      final visited = <String>{};
      final queue = <String>[start.id];
      bool hasNonStartAfter = false;
      while (queue.isNotEmpty) {
        final cur = queue.removeAt(0);
        if (!visited.add(cur)) continue;
        for (final e in s.flowchart.edges) {
          if (e.from == cur) {
            final next = s.getNodeById(e.to);
            if (next == null) continue;
            if (next.kind != FlowNodeKind.start) {
              hasNonStartAfter = true;
              break;
            }
            queue.add(next.id);
          }
        }
        if (hasNonStartAfter) break;
      }
      if (!hasNonStartAfter) {
        emit(const FlowchartActionFailure(
          title: 'Operazione non valida',
          message: 'Aggiungi prima almeno un blocco dopo "Inizio" prima di creare un ciclo do-while.',
        ));
        emit(s);
        return;
      }
    }

    // Determina la dimensione del nuovo nodo
    final newNodeSize = _getNodeSize(event.kind);

    // Usa PlacementEngine per trovare la posizione ottimale
    final position = PlacementEngine.findOptimalPosition(
      fromNode: sourceNode,
      newNodeSize: newNodeSize,
      existingNodes: s.flowchart.nodes,
      canvasConstraints: event.canvasConstraints,
    );

    if (position == null) {
      emit(const FlowchartActionFailure(
        title: 'Spazio insufficiente',
        message: 'Non c\'è spazio disponibile per creare il nodo.',
      ));
      emit(s);
      return;
    }

    // Crea il nuovo nodo usando FlowNodeFactory
    final newNode = FlowNodeFactory.createNode(
      event.kind,
      position,
      allVariables: s.flowchart.variables,
      initialData: event.initialData,
    );

    // Crea gli edge: collega il source node e tutti i nodi foglia selezionati al nuovo nodo
    final newEdges = <FlowchartEdge>[];

    // Edge dal nodo sorgente al nuovo nodo
    // REQ: In modalità connettore ciclo NON collegare dal nodo ciclo/condizione
    if (s.connectorPurpose != ConnectorPurpose.loopClosure) {
      newEdges.add(FlowchartEdge(
        from: s.connectorSourceNodeId!,
        to: newNode.id,
      ));
    }

    // Edge dai nodi foglia selezionati al nuovo nodo
    for (final selectedNodeId in s.selectedConnectorNodeIds) {
      newEdges.add(FlowchartEdge(
        from: selectedNodeId,
        to: newNode.id,
      ));
    }

    // Se in modalità loopClosure ma non è stato selezionato alcun foglia, blocca
    if (s.connectorPurpose == ConnectorPurpose.loopClosure && newEdges.isEmpty) {
      emit(const FlowchartActionFailure(
        title: 'Selezione mancante',
        message: 'Seleziona almeno un nodo foglia del ciclo da collegare al nuovo blocco.',
      ));
      emit(s);
      return;
    }

    // Valida tutte le connessioni
    final validator = rules.FlowchartValidator();
    for (final edge in newEdges) {
      final validation = validator.validate(s, edge);
      if (!validation.isValid) {
        emit(FlowchartActionFailure(
          title: 'Connessione non permessa',
          message: validation.errorMessage ?? '',
        ));
        emit(s);
        return;
      }
    }

    final updatedFlowchart = s.flowchart.copyWith(
      nodes: [...s.flowchart.nodes, newNode],
      edges: [...s.flowchart.edges, ...newEdges],
    );

    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updatedFlowchart,
      description: 'Applica connettore e crea nodo ${event.kind.name}',
    );
    _history.executeCommand(command);

    emit(command.execute(s).copyWith(
      isConnectorModeActive: false,
      clearConnectorSource: true,
      selectedConnectorNodeIds: {},
      connectorPurpose: null,
    ));
  }

  void _onCancelConnectorMode(CancelConnectorMode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    emit(s.copyWith(
      isConnectorModeActive: false,
      clearConnectorSource: true,
      selectedConnectorNodeIds: {},
      connectorPurpose: null,
    ));
  }

  void _onStartDoWhileBodySelection(StartDoWhileBodySelection event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // Se è già attiva un'altra modalità diversa da do-while, blocca
    if (s.isConnectorModeActive && s.connectorPurpose != ConnectorPurpose.doWhileBody) {
      emit(const FlowchartActionFailure(
        title: 'Operazione non disponibile',
        message: 'Completa o annulla la modalità attiva prima di selezionare il corpo del do-while.',
      ));
      emit(s);
      return;
    }

    final loop = s.getNodeById(event.doWhileNodeId);
    if (loop == null || loop.kind != FlowNodeKind.doWhileLoop) {
      emit(const FlowchartActionFailure(
        title: 'Selezione non valida',
        message: 'Seleziona un ciclo post-condizionale valido.',
      ));
      emit(s);
      return;
    }

    emit(s.copyWith(
      isConnectorModeActive: true,
      selectedConnectorNodeIds: {},
      connectorSourceNodeId: loop.id,
      connectorPurpose: ConnectorPurpose.doWhileBody,
      selectedNodeId: loop.id,
    ));
  }

  void _onCloseLoop(CloseLoop event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    final from = s.getNodeById(event.fromNodeId);
    final loop = s.getNodeById(event.loopNodeId);
    if (from == null || loop == null) return;

    // ✅ FIX: Verifica che il nodo di destinazione sia un ciclo (while o do-while)
    if (loop.kind != FlowNodeKind.doWhileLoop && loop.kind != FlowNodeKind.whileLoop) {
      emit(const FlowchartActionFailure(
        title: 'Destinazione non valida',
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

    // 🆕 Merge in un'unica azione: se l'ultimo comando è l'aggiunta del do-while, sostituiscilo con uno combinato
    final last = _history.peekLastUndo();
    if (last is UpdateFlowchartCommand) {
      final lastNew = last.newFlowchart;
      final lastHasLoop = lastNew.nodes.any((n) => n.id == loop.id && n.kind == FlowNodeKind.doWhileLoop);
      final lastHasBodyStart = lastNew.edges.any((e) => e.from == loop.id && (e.port == 'true' || e.port == 'doWhileStart'));
      // Condizione: l'ultimo comando ha creato (o modificato) il do-while senza l'edge del corpo
      if (lastHasLoop && !lastHasBodyStart) {
        final merged = UpdateFlowchartCommand(
          oldFlowchart: last.oldFlowchart,
          newFlowchart: updated,
          description: 'Crea do-while + seleziona inizio corpo (atomico)',
        );
        _history.replaceLastUndo(merged);
        emit(merged.execute(s).copyWith(
          isConnectorModeActive: false,
          clearConnectorSource: true,
          selectedConnectorNodeIds: {},
          connectorPurpose: null,
          selectedNodeId: loop.id,
        ));
        return;
      }
    }

    // Fallback: comportati come prima (azione separata)
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

    final afterReset = cmd.execute(s);

    // 🆕 Se il nodo target è un do-while, riapri la selezione dell'inizio del corpo se ci sono candidati
    if (target.kind == FlowNodeKind.doWhileLoop) {
      if (afterReset.hasEligibleDoWhileBodyCandidates(target.id)) {
        emit(afterReset.copyWith(
          isConnectorModeActive: true,
          connectorSourceNodeId: target.id,
          selectedConnectorNodeIds: {},
          connectorPurpose: ConnectorPurpose.doWhileBody,
          selectedNodeId: target.id,
        ));
        return;
      }
    }

    emit(afterReset.copyWith(
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

    // Se una modalità è già attiva ed è diversa da reset, blocca
    if (s.isConnectorModeActive && s.connectorPurpose != ConnectorPurpose.resetFromNode) {
      emit(const FlowchartActionFailure(
        title: 'Operazione non disponibile',
        message: 'Completa o annulla la modalità attiva prima di usare il reset.',
      ));
      emit(s);
      return;
    }

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

  void _onSetDebugMode(SetDebugMode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    emit(s.copyWith(isDebugMode: event.isDebugMode));
  }

  void _onStartLoopClosureMode(StartLoopClosureMode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    // Se è già attiva un'altra modalità speciale, blocca
    if (s.isConnectorModeActive && s.connectorPurpose != ConnectorPurpose.normal) {
      emit(const FlowchartActionFailure(
        title: 'Operazione non disponibile',
        message: 'Completa o annulla la modalità attiva prima di usare la chiusura del ciclo.',
      ));
      emit(s);
      return;
    }

    final loop = s.getNodeById(event.loopNodeId);
    if (loop == null || (loop.kind != FlowNodeKind.whileLoop && loop.kind != FlowNodeKind.doWhileLoop)) {
      emit(const FlowchartActionFailure(
        title: 'Nodo ciclo non valido',
        message: 'Seleziona un ciclo valido per chiudere.',
      ));
      emit(s);
      return;
    }

    emit(s.copyWith(
      isConnectorModeActive: true,
      connectorSourceNodeId: loop.id,
      selectedConnectorNodeIds: {},
      connectorPurpose: ConnectorPurpose.loopClosure,
      selectedNodeId: loop.id,
    ));
  }

  void _onApplyLoopClosure(ApplyLoopClosure event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;

    if (s.connectorSourceNodeId == null || s.selectedConnectorNodeIds.isEmpty) {
      emit(const FlowchartActionFailure(
        title: 'Nessun nodo selezionato',
        message: 'Seleziona almeno 2 nodi foglia da collegare al ciclo.',
      ));
      emit(s);
      return;
    }

    if (s.selectedConnectorNodeIds.length < 2) {
      emit(const FlowchartActionFailure(
        title: 'Selezione insufficiente',
        message: 'Seleziona almeno 2 nodi foglia per usare il connettore ciclo.',
      ));
      emit(s);
      return;
    }

    final loopNode = s.getNodeById(event.loopNodeId);
    if (loopNode == null || (loopNode.kind != FlowNodeKind.whileLoop && loopNode.kind != FlowNodeKind.doWhileLoop)) {
      emit(const FlowchartActionFailure(
        title: 'Nodo ciclo non valido',
        message: 'Il nodo di destinazione non è un ciclo valido.',
      ));
      emit(s);
      return;
    }

    // 🆕 NUOVO: Crea gli archi di chiusura per tutti i nodi selezionati direttamente al ciclo
    // La convergenza sarà gestita solo visivamente nel painter
    final newEdges = <FlowchartEdge>[];
    final validator = rules.FlowchartValidator();

    for (final selectedNodeId in s.selectedConnectorNodeIds) {
      // Verifica che il nodo sia effettivamente nel corpo del ciclo
      final parentLoopId = s.getParentLoopNodeId(selectedNodeId);
      if (parentLoopId != event.loopNodeId) {
        emit(FlowchartActionFailure(
          title: 'Nodo fuori ciclo',
          message: 'Il nodo $selectedNodeId non appartiene a questo ciclo.',
        ));
        emit(s);
        return;
      }

      // Verifica che non esista già l'arco
      final alreadyExists = s.flowchart.edges.any(
        (e) => e.from == selectedNodeId && e.to == event.loopNodeId && e.port == 'loop',
      );
      if (alreadyExists) continue;

      // Arco di chiusura diretto dal nodo al ciclo
      final loopClosureEdge = FlowchartEdge(
        from: selectedNodeId,
        to: event.loopNodeId,
        port: 'loop',
      );

      // Valida l'arco
      final validation = validator.validate(s, loopClosureEdge);
      if (!validation.isValid) {
        emit(FlowchartActionFailure(
          title: 'Connessione non permessa',
          message: validation.errorMessage ?? '',
        ));
        emit(s);
        return;
      }

      newEdges.add(loopClosureEdge);
    }

    if (newEdges.isEmpty) {
      // Nessun arco da aggiungere (tutti già esistenti)
      emit(s.copyWith(
        isConnectorModeActive: false,
        clearConnectorSource: true,
        selectedConnectorNodeIds: {},
        connectorPurpose: null,
      ));
      return;
    }

    // Aggiorna il flowchart con gli archi di chiusura
    final updatedFlowchart = s.flowchart.copyWith(
      edges: [...s.flowchart.edges, ...newEdges],
    );

    final command = UpdateFlowchartCommand(
      oldFlowchart: s.flowchart,
      newFlowchart: updatedFlowchart,
      description: 'Applica connettore ciclo (${s.selectedConnectorNodeIds.length} nodi → ciclo)',
    );
    _history.executeCommand(command);

    emit(command.execute(s).copyWith(
      isConnectorModeActive: false,
      clearConnectorSource: true,
      selectedConnectorNodeIds: {},
      connectorPurpose: null,
    ));
  }
}
