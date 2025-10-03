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
  final List<String> debugPath;
  final int debugIndex;

  // ✨ NUOVE PROPRIETÀ PER LA MODALITÀ CONNETTORE
  final bool isConnectorModeActive;
  final String? connectorSourceNodeId; // L'ID del nodo da cui è partita l'azione
  final Set<String> selectedConnectorNodeIds; // Gli ID dei nodi foglia selezionati

  static const _uuid = Uuid();

  const FlowchartLoaded({
    required this.flowchart,
    this.selectedNodeId,
    this.isDebugMode = false,
    this.debugPath = const [],
    this.debugIndex = 0,
    // ✨ INIZIALIZZA LE NUOVE PROPRIETÀ
    this.isConnectorModeActive = false,
    this.connectorSourceNodeId,
    this.selectedConnectorNodeIds = const {},
  });

  factory FlowchartLoaded.empty({String? fileName}) {
    // Nota: la factory 'empty' non ha bisogno delle nuove proprietà
    // perché i loro valori di default sono già corretti.
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


  bool isLeafNode(String nodeId) {
    return !flowchart.edges.any((edge) => edge.from == nodeId);
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
    // ✨ GESTISCI LE NUOVE PROPRIETÀ NEL copyWith
    bool? isConnectorModeActive,
    String? connectorSourceNodeId,
    Set<String>? selectedConnectorNodeIds,
    bool clearConnectorSource = false, // Utility per resettare il sourceId a null
  }) {
    return FlowchartLoaded(
      flowchart: flowchart ?? this.flowchart,
      selectedNodeId:
      clearSelection ? null : (selectedNodeId ?? this.selectedNodeId),
      isDebugMode: isDebugMode ?? this.isDebugMode,
      debugPath: debugPath ?? this.debugPath,
      debugIndex: debugIndex ?? this.debugIndex,
      isConnectorModeActive:
      isConnectorModeActive ?? this.isConnectorModeActive,
      connectorSourceNodeId: clearConnectorSource
          ? null
          : (connectorSourceNodeId ?? this.connectorSourceNodeId),
      selectedConnectorNodeIds:
      selectedConnectorNodeIds ?? this.selectedConnectorNodeIds,
    );
  }

  FlowchartLoaded deselect() {
    return copyWith(clearSelection: true);
  }

  // ✨ AGGIORNA LE PROPS DI EQUATABLE
  @override
  List<Object?> get props => [
    flowchart,
    selectedNodeId,
    isDebugMode,
    debugPath,
    debugIndex,
    isConnectorModeActive,
    connectorSourceNodeId,
    selectedConnectorNodeIds,
  ];
}

class ShowNodeCreationDialog extends FlowchartState {
  final FlowNodeKind kind;
  final String fromNodeId;
  final String? fromPort;
  final List<VariableDeclaration> availableVariables;

  const ShowNodeCreationDialog({
    required this.kind,
    required this.fromNodeId,
    this.fromPort,
    required this.availableVariables,
  });

  @override
  List<Object?> get props => [kind, fromNodeId, fromPort, availableVariables];
}