import 'dart:ui';
import 'package:bloc/bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';
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
    on<ResetFlowchart>(_onResetFlowchart);
    on<ClearHistory>(_onClearHistory);
    on<DebugFlowchart>(_onDebugFlowchart);
    on<DebugNextNode>(_onDebugNext);
    on<DebugPrevNode>(_onDebugPrev);
    on<DebugExit>(_onDebugExit);
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  dynamic _parseValue(String type, String value) {
    if (value.isEmpty) return null;
    switch (type) {
      case 'int':
        return int.tryParse(value);
      case 'float':
      case 'double':
        return double.tryParse(value);
      case 'bool':
        return ['true', '1'].contains(value.toLowerCase());
      case 'char':
        if (value.length > 1 && value.startsWith("'") && value.endsWith("'")) {
          return value.substring(1, value.length - 1);
        }
        return value;
      case 'string':
        if (value.length > 1 && value.startsWith('"') && value.endsWith('"')) {
          return value.substring(1, value.length - 1);
        }
        return value;
      default:
        return value;
    }
  }

  List<VariableDeclaration> _recalculateGlobalVariablesAndAssignments(List<FlowNode> nodes) {
    final variableMap = <String, VariableDeclaration>{};

    for (final node in nodes) {
      if (node is InputNode) {
        for (final decl in node.declarations) {
          variableMap.putIfAbsent(decl.name, () => decl);
        }
      }
    }

    for (final node in nodes) {
      if (node is InputNode) {
        for (final assignment in node.assignments) {
          final targetName = assignment.target;
          if (variableMap.containsKey(targetName)) {
            final targetVar = variableMap[targetName]!;
            final dynamic newValue = _parseValue(targetVar.dataType, assignment.expression);
            variableMap[targetName] = targetVar.copyWith(defaultValue: newValue);
          }
        }
      }
    }
    return variableMap.values.toList();
  }

  FlowNode _createUpdatedNode(FlowNode oldNode, Map<String, dynamic> newData) {
    if (oldNode is InputNode) {
      final newDeclarations = (newData['declarations'] as List<Map<String, dynamic>>?)
          ?.map((d) => VariableDeclaration.fromMap(d))
          .toList();
      final newAssignments = (newData['assignments'] as List<Map<String, dynamic>>?)
          ?.map((a) => Assignment.fromMap(a))
          .toList();

      return oldNode.copyWith(
        text: newData['text'] as String?,
        declarations: newDeclarations,
        assignments: newAssignments,
      );
    } else if (oldNode is ProcessNode) {
      return oldNode.copyWith(
        flowchartToCall: newData['flowchartToCall'] as String?,
        arguments: (newData['arguments'] as List?)?.cast<String>(),
        resultTarget: newData['resultTarget'] as String?,
      );
    } else if (oldNode is DecisionNode) {
      return oldNode.copyWith(condition: newData['condition'] as String?);
    } else if (oldNode is OutputNode) {
      return oldNode.copyWith(
          template: newData['template'] as String?,
          variables: (newData['variables'] as List?)?.cast<String>());
    }
    return oldNode;
  }

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    _history.clear();
    final loadedState = FlowchartLoaded.fromJson(event.jsonContent);
    final currentSelection = (state is FlowchartLoaded) ? (state as FlowchartLoaded).selectedNodeId : null;
    final flowchartWithName = loadedState.flowchart.copyWith(name: event.fileName);
    String? finalSelection = currentSelection;
    if (currentSelection != null && !flowchartWithName.nodes.any((n) => n.id == currentSelection)) {
      finalSelection = null;
    }
    emit(loadedState.copyWith(flowchart: flowchartWithName, selectedNodeId: finalSelection));
  }

  void _onAddNode(AddNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final fromNode = currentState.getNodeById(event.fromNodeId);
    if (fromNode == null) return;

    final potentialNode = FlowNodeFactory.createNode(event.kind, Offset.zero, initialData: event.initialData);
    final optimalPosition = PlacementEngine.findOptimalPosition(
      fromNode: fromNode,
      newNodeSize: Size(potentialNode.width, potentialNode.height),
      existingNodes: currentState.flowchart.nodes,
      canvasConstraints: event.canvasConstraints,
      fromPort: event.fromPort,
    );
    if (optimalPosition == null) return;

    final newNode = (potentialNode as dynamic).copyWith(x: optimalPosition.dx, y: optimalPosition.dy) as FlowNode;
    final newEdge = FlowchartEdge(from: fromNode.id, to: newNode.id, port: event.fromPort);
    final newNodes = [...currentState.flowchart.nodes, newNode];
    final newEdges = [...currentState.flowchart.edges, newEdge];
    final newVariables = _recalculateGlobalVariablesAndAssignments(newNodes);
    final newFlowchart = currentState.flowchart.copyWith(nodes: newNodes, edges: newEdges, variables: newVariables);

    final command = UpdateFlowchartCommand(oldFlowchart: currentState.flowchart, newFlowchart: newFlowchart, description: 'Aggiungi nodo');
    _history.executeCommand(command);
    emit(command.execute(currentState).copyWith(selectedNodeId: newNode.id));
  }

  void _onRemoveNode(RemoveNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final nodeToRemove = currentState.getNodeById(event.nodeId);
    if (nodeToRemove == null || nodeToRemove.kind == FlowNodeKind.start) return;

    final incomingEdges = currentState.flowchart.edges.where((e) => e.to == nodeToRemove.id).toList();
    String? parentId = incomingEdges.isNotEmpty ? incomingEdges.first.from : null;

    final newNodes = currentState.flowchart.nodes.where((n) => n.id != event.nodeId).toList();
    final newEdges = currentState.flowchart.edges.where((e) => e.to != event.nodeId && e.from != event.nodeId).toList();
    final newVariables = _recalculateGlobalVariablesAndAssignments(newNodes);
    final newFlowchart = currentState.flowchart.copyWith(nodes: newNodes, edges: newEdges, variables: newVariables);

    final command = UpdateFlowchartCommand(oldFlowchart: currentState.flowchart, newFlowchart: newFlowchart, description: 'Rimuovi nodo');
    _history.executeCommand(command);
    emit(command.execute(currentState).copyWith(selectedNodeId: parentId, clearSelection: parentId == null));
  }

  void _onUpdateNodeContent(UpdateNodeContent event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final oldNode = currentState.getNodeById(event.nodeId);
    if (oldNode == null) return;

    final updatedNode = _createUpdatedNode(oldNode, event.newData);
    final newNodes = currentState.flowchart.nodes.map((n) => n.id == event.nodeId ? updatedNode : n).toList();
    final newVariables = _recalculateGlobalVariablesAndAssignments(newNodes);
    final newFlowchart = currentState.flowchart.copyWith(nodes: newNodes, variables: newVariables);

    final command = UpdateFlowchartCommand(oldFlowchart: currentState.flowchart, newFlowchart: newFlowchart, description: 'Aggiorna contenuto');
    _history.executeCommand(command);
    emit(command.execute(currentState));
  }

  void _onUpdateNodePosition(UpdateNodePosition event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final newNodes = currentState.flowchart.nodes.map((n) {
      return n.id == event.nodeId ? (n as dynamic).copyWith(x: event.newX, y: event.newY) as FlowNode : n;
    }).toList();
    final newFlowchart = currentState.flowchart.copyWith(nodes: newNodes);

    final command = UpdateFlowchartCommand(oldFlowchart: currentState.flowchart, newFlowchart: newFlowchart, description: 'Sposta nodo');
    if (event.newX != event.oldX || event.newY != event.oldY) {
      _history.executeCommand(command);
    }
    emit(command.execute(currentState));
  }

  void _onLinkToExistingEnd(LinkToExistingEnd event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final endNode = currentState.flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.end);
    final newEdge = FlowchartEdge(from: event.fromNodeId, to: endNode.id, port: event.fromPort);
    final newFlowchart = currentState.flowchart.copyWith(edges: [...currentState.flowchart.edges, newEdge]);

    final command = UpdateFlowchartCommand(oldFlowchart: currentState.flowchart, newFlowchart: newFlowchart, description: 'Collega a Fine');
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
    if (state is FlowchartLoaded && _history.canUndo) {
      final command = _history.undo();
      if (command != null) emit(command.undo(state as FlowchartLoaded));
    }
  }

  void _onRedo(Redo event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded && _history.canRedo) {
      final command = _history.redo();
      if (command != null) emit(command.execute(state as FlowchartLoaded));
    }
  }

  void _onResetFlowchart(ResetFlowchart event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    _history.clear();
    final startNode = currentState.flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.start);
    final newFlowchart = currentState.flowchart.copyWith(nodes: [startNode], edges: [], variables: []);
    emit(FlowchartLoaded(flowchart: newFlowchart, selectedNodeId: startNode.id));
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

    final path = _calculateDebugPath(s, start.id);
    if (path.isEmpty) return;
    emit(s.copyWith(
      isDebugMode: true,
      debugPath: path,
      debugIndex: 0,
      selectedNodeId: path.first,
    ));
  }

  void _onDebugNext(DebugNextNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode) return;
    final nextIndex = (s.debugIndex + 1).clamp(0, s.debugPath.length - 1);
    if (nextIndex == s.debugIndex) return;
    final newNodeId = s.debugPath[nextIndex];
    emit(s.copyWith(debugIndex: nextIndex, selectedNodeId: newNodeId));
  }

  void _onDebugPrev(DebugPrevNode event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    if (!s.isDebugMode) return;
    final prevIndex = (s.debugIndex - 1).clamp(0, s.debugPath.length - 1);
    if (prevIndex == s.debugIndex) return;
    final newNodeId = s.debugPath[prevIndex];
    emit(s.copyWith(debugIndex: prevIndex, selectedNodeId: newNodeId));
  }

  void _onDebugExit(DebugExit event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final s = state as FlowchartLoaded;
    emit(s.copyWith(isDebugMode: false, debugPath: const [], debugIndex: 0, clearSelection: true));
  }

  List<String> _calculateDebugPath(FlowchartLoaded s, String startNodeId) {
    final List<String> path = [];
    final visited = <String>{};
    String? currentId = startNodeId;
    while (currentId != null && currentId.isNotEmpty && !visited.contains(currentId)) {
      path.add(currentId);
      visited.add(currentId);
      final outgoing = s.flowchart.edges.where((e) => e.from == currentId).toList();
      if (outgoing.isEmpty) break;
      final next = outgoing.firstWhere((e) => e.port != 'false', orElse: () => outgoing.first);
      currentId = next.to;
    }
    return path;
  }
}