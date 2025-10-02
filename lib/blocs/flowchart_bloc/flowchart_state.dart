import 'dart:convert';
import 'dart:developer';
import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:uuid/uuid.dart';

abstract class FlowchartState extends Equatable {
  const FlowchartState();
  @override
  List<Object?> get props => [];
}

class FlowchartInitial extends FlowchartState {}

class FlowchartActionFailure extends FlowchartState {
  final String title;
  final String message;

  const FlowchartActionFailure({required this.title, required this.message});

  @override
  List<Object?> get props => [title, message];
}

class FlowchartLoaded extends FlowchartState {
  final Flowchart flowchart;
  final String? selectedNodeId;
  final bool isDebugMode;
  final List<String> debugPath; // lista di nodeId in ordine di visita
  final int debugIndex; // indice del nodo corrente dentro debugPath

  static const _uuid = Uuid();

  const FlowchartLoaded({
    required this.flowchart,
    this.selectedNodeId,
    this.isDebugMode = false,
    this.debugPath = const [],
    this.debugIndex = 0,
  });

  factory FlowchartLoaded.empty({String? fileName}) {
    return FlowchartLoaded(
      flowchart: Flowchart(
        flowchartId: _uuid.v4(),
        name: fileName ?? 'Nuovo Flowchart',
        schemaVersion: kFlowNodeSchemaVersion,
        nodes: const [],
        edges: const [],
        signature: const FlowchartSignature(),
        variables: const [],
      ),
    );
  }

  FlowNode? getNodeById(String id) {
    try {
      return flowchart.nodes.firstWhere((node) => node.id == id);
    } catch (e) {
      return null;
    }
  }

  List<FlowchartEdge> getOutgoingEdges(String nodeId) {
    return flowchart.edges.where((edge) => edge.from == nodeId).toList();
  }

  bool canAddOutgoingConnection(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null) return false;

    final maxConnections = switch (node.kind) {
      FlowNodeKind.decision => 2,
      FlowNodeKind.end => 0,
      _ => 1,
    };

    return getOutgoingEdges(nodeId).length < maxConnections;
  }

  factory FlowchartLoaded.fromJson(String jsonString) {
    if (jsonString.isEmpty) {
      return FlowchartLoaded.empty();
    }
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      final entity = FlowchartEntity.fromDocument(decoded);
      final flowchart = Flowchart.fromEntity(entity);
      return FlowchartLoaded(flowchart: flowchart);
    } catch (e, stackTrace) {
      log("Errore nel parsing del JSON del flowchart: $e",
          stackTrace: stackTrace);
      return FlowchartLoaded.empty();
    }
  }

  String toJson() {
    final entity = flowchart.toEntity();
    return jsonEncode(entity.toDocument());
  }

  FlowchartLoaded copyWith({
    Flowchart? flowchart,
    String? selectedNodeId,
    bool clearSelection = false,
    bool? isDebugMode,
    List<String>? debugPath,
    int? debugIndex,
  }) {
    return FlowchartLoaded(
      flowchart: flowchart ?? this.flowchart,
      selectedNodeId:
          clearSelection ? null : (selectedNodeId ?? this.selectedNodeId),
      isDebugMode: isDebugMode ?? this.isDebugMode,
      debugPath: debugPath ?? this.debugPath,
      debugIndex: debugIndex ?? this.debugIndex,
    );
  }

  FlowchartLoaded deselect() {
    return copyWith(clearSelection: true);
  }

  @override
  List<Object?> get props => [flowchart, selectedNodeId, isDebugMode, debugPath, debugIndex];
}

// In flowchart_state.dart

// Questo stato "comando" non sostituisce FlowchartLoaded,
// ma viene usato da un BlocListener per triggerare un'azione.
class ShowNodeCreationDialog extends FlowchartState {
  final FlowNodeKind kind;
  final String fromNodeId;
  final String? fromPort;
  final List<VariableDeclaration> availableVariables;
  // Aggiungi altri dati se necessario per altri dialoghi

  const ShowNodeCreationDialog({
    required this.kind,
    required this.fromNodeId,
    this.fromPort,
    required this.availableVariables,
  });

  @override
  List<Object?> get props => [kind, fromNodeId, fromPort, availableVariables];
}
