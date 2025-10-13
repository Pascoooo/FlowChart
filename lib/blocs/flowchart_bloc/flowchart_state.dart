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

// ✨ Nuovo: scopo della modalità connettore
enum ConnectorPurpose { normal, doWhileBody, resetFromNode }

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

  // ⚠️ NUOVO: Traccia se è la prima volta che entriamo in debug (per lo zoom)
  final bool isDebugJustStarted;

  // ✨ NUOVE PROPRIETÀ PER LA MODALITÀ CONNETTORE
  final bool isConnectorModeActive;
  final String? connectorSourceNodeId; // L'ID del nodo da cui è partita l'azione
  final Set<String> selectedConnectorNodeIds; // Gli ID dei nodi foglia selezionati
  final ConnectorPurpose? connectorPurpose; // ✨ NUOVO: scopo della modalità connettore

  // NEW: Risultati decisione valutati ma non ancora applicati (nodeId -> result)
  final Map<String, bool> decisionSelections;

  // 🆕 NUOVO: Stack di chiamate per sottoprogrammi
  final CallStack callStack;

  // 🆕 NUOVO: Tutti i flowchart del progetto (per risolvere le chiamate)
  final Map<String, Flowchart> projectFlowcharts;

  static const _uuid = Uuid();

  const FlowchartLoaded({
    required this.flowchart,
    this.selectedNodeId,
    this.isDebugMode = false,
    this.debugPath = const [],
    this.debugIndex = 0,
    this.isDebugJustStarted = false,
    // ✨ INIZIALIZZA LE NUOVE PROPRIETÀ
    this.isConnectorModeActive = false,
    this.connectorSourceNodeId,
    this.selectedConnectorNodeIds = const {},
    this.connectorPurpose, // ✨ NUOVO
    this.decisionSelections = const {}, // NEW default
    this.callStack = const CallStack(), // 🆕 NUOVO
    this.projectFlowcharts = const {}, // 🆕 NUOVO
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

  List<FlowchartEdge> getIncomingEdges(String nodeId) {
    return flowchart.edges.where((edge) => edge.to == nodeId).toList();
  }

  /// Restituisce l'insieme degli ID dei nodi da cui esiste un percorso al target
  /// (nodi "prima" del target nel flusso), escludendo il target stesso.
  Set<String> nodesThatCanReach(String targetNodeId) {
    final ancestors = <String>{};
    final stack = <String>[targetNodeId];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final e in getIncomingEdges(current)) {
        final fromId = e.from;
        if (fromId.isEmpty || fromId == targetNodeId) continue;
        if (ancestors.add(fromId)) {
          stack.add(fromId);
        }
      }
    }
    ancestors.remove(targetNodeId);
    return ancestors;
  }

  bool isLeafNode(String nodeId) {
    return !flowchart.edges.any((edge) => edge.from == nodeId);
  }

  bool canAddOutgoingConnection(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null) return false;

    final maxConnections = switch (node.kind) {
      FlowNodeKind.decision => 2,
      FlowNodeKind.whileLoop => 2,
      FlowNodeKind.doWhileLoop => 2,
      FlowNodeKind.end => 0,
      _ => 1,
    };

    return getOutgoingEdges(nodeId).length < maxConnections;
  }

  /// Determina se un nodo è all'interno di un ciclo (while o do-while)
  /// Ritorna l'ID del nodo ciclo genitore, o null se non è in un ciclo
  String? getParentLoopNodeId(String nodeId) {
    // Un nodo è in un ciclo if esiste un percorso da un nodo loop a questo nodo
    // attraverso il ramo 'true' (che rappresenta il corpo del ciclo)

    for (final node in flowchart.nodes) {
      if (node.kind == FlowNodeKind.whileLoop) {
        // Per il while: trova l'arco 'true' del ciclo (che entra nel corpo del ciclo)
        final trueEdge = flowchart.edges.firstWhere(
          (e) => e.from == node.id && e.port == 'true',
          orElse: () => const FlowchartEdge(from: '', to: ''),
        );

        if (trueEdge.from.isNotEmpty) {
          // Verifica se il nodo corrente è raggiungibile dal ramo true
          if (_isReachableFrom(trueEdge.to, nodeId, node.id)) {
            return node.id;
          }
        }
      } else if (node.kind == FlowNodeKind.doWhileLoop) {
        // Per il do-while: il corpo parte dalla porta 'true' (standard) o, in legacy, da 'doWhileStart'
        FlowchartEdge startEdge = flowchart.edges.firstWhere(
          (e) => e.from == node.id && e.port == 'true',
          orElse: () => const FlowchartEdge(from: '', to: ''),
        );

        if (startEdge.from.isEmpty) {
          // Fallback legacy: supporta vecchia porta 'doWhileStart'
          startEdge = flowchart.edges.firstWhere(
            (e) => e.from == node.id && e.port == 'doWhileStart',
            orElse: () => const FlowchartEdge(from: '', to: ''),
          );
        }

        if (startEdge.from.isNotEmpty) {
          // Verifica se il nodo corrente è raggiungibile dall'inizio del corpo
          if (_isReachableFrom(startEdge.to, nodeId, node.id)) {
            return node.id;
          }
        }
      }
    }
    return null;
  }

  /// Verifica se 'target' è raggiungibile da 'start' senza passare per 'loopNodeId'
  bool _isReachableFrom(String start, String target, String loopNodeId) {
    if (start == target) return true;
    if (start == loopNodeId) return false; // Non rientrare nel nodo loop

    final visited = <String>{};
    final queue = <String>[start];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (current == target) return true;
      if (visited.contains(current)) continue;
      visited.add(current);

      // Aggiungi tutti i nodi successivi (eccetto il loop node stesso)
      for (final edge in flowchart.edges) {
        if (edge.from == current && edge.to != loopNodeId && !visited.contains(edge.to)) {
          // Escludi gli archi 'loop' dalla ricerca in avanti
          if (edge.port != 'loop') {
            queue.add(edge.to);
          }
        }
      }
    }
    return false;
  }

  /// Verifica se un nodo è dentro un ciclo
  bool isInsideLoop(String nodeId) {
    return getParentLoopNodeId(nodeId) != null;
  }

  /// Verifica se un candidato può essere l'inizio del corpo di un do-while
  /// Regole:
  /// - deve esistere un percorso dal candidato al nodo do-while (antenato raggiungibile)
  /// - non può essere il nodo 'Inizio'
  /// - non può essere il do-while stesso
  bool isValidDoWhileBodyStart(String doWhileNodeId, String candidateNodeId) {
    final candidate = getNodeById(candidateNodeId);
    if (candidate == null) return false;
    if (candidate.kind == FlowNodeKind.start) return false;
    if (candidateNodeId == doWhileNodeId) return false;

    final ancestors = nodesThatCanReach(doWhileNodeId);
    return ancestors.contains(candidateNodeId);
  }

  /// Restituisce gli archi in uscita da [nodeId] che restano nel ramo che
  /// conduce a [targetNodeId]. Includi opzionalmente l'arco di chiusura 'loop'.
  List<FlowchartEdge> getOutgoingEdgesTowardTarget(
    String nodeId,
    String targetNodeId, {
    bool includeLoopClosure = true,
  }) {
    final toward = nodesThatCanReach(targetNodeId);
    return flowchart.edges.where((e) {
      if (e.from != nodeId) return false;
      // Arco di chiusura del ciclo
      if (includeLoopClosure && e.port == 'loop' && e.to == targetNodeId) {
        return true;
      }
      // Altri archi consentiti solo se portano verso un nodo che può raggiungere il target
      return toward.contains(e.to);
    }).toList();
  }

  /// Restituisce gli ID dei nodi successivi a [nodeId] limitati al ramo che
  /// conduce a [targetNodeId]. Utile per presentare "figli" coerenti con il ciclo.
  List<String> nextNodesTowardTarget(
    String nodeId,
    String targetNodeId, {
    bool includeLoopClosure = true,
  }) {
    return getOutgoingEdgesTowardTarget(
      nodeId,
      targetNodeId,
      includeLoopClosure: includeLoopClosure,
    ).map((e) => e.to).toList();
  }

  /// Calcola l'insieme dei nodi che compongono il corpo del do-while identificato da [doWhileNodeId].
  /// Strategia:
  /// - trova l'arco di avvio del corpo ('true' o legacy 'doWhileStart')
  /// - esegue una BFS dal nodo di avvio seguendo solo archi non-'loop'
  /// - interseca il risultato con gli antenati del do-while (nodesThatCanReach)
  ///   per escludere rami che non rientrano nel ciclo
  Set<String> doWhileBodyNodes(String doWhileNodeId) {
    final loop = getNodeById(doWhileNodeId);
    if (loop == null || loop.kind != FlowNodeKind.doWhileLoop) return <String>{};

    // Trova l'arco di avvio del corpo
    FlowchartEdge startEdge = flowchart.edges.firstWhere(
      (e) => e.from == doWhileNodeId && e.port == 'true',
      orElse: () => const FlowchartEdge(from: '', to: ''),
    );
    if (startEdge.from.isEmpty) {
      startEdge = flowchart.edges.firstWhere(
        (e) => e.from == doWhileNodeId && e.port == 'doWhileStart',
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );
    }
    if (startEdge.from.isEmpty) return <String>{};

    // Visita in avanti ignorando archi di rientro 'loop'
    final visited = <String>{};
    final queue = <String>[startEdge.to];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current)) continue;

      for (final e in flowchart.edges) {
        if (e.from == current && e.port != 'loop') {
          queue.add(e.to);
        }
      }
    }

    // Tieni solo i nodi che possono effettivamente raggiungere il do-while (chiudono il ciclo)
    final ancestors = nodesThatCanReach(doWhileNodeId);
    visited.retainAll(ancestors);
    return visited;
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

  /// Parser sicuro: restituisce null se il JSON non  e8 parseabile,
  /// evitando di resettare a un flowchart vuoto.
  static FlowchartLoaded? tryParse(String jsonString) {
    if (jsonString.trim().isEmpty) return null;
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      final entity = FlowchartEntity.fromDocument(decoded);
      final flowchart = Flowchart.fromEntity(entity);
      return FlowchartLoaded(flowchart: flowchart);
    } catch (e, stackTrace) {
      log("FlowchartLoaded.tryParse: parsing fallito: $e", stackTrace: stackTrace);
      return null;
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
    bool? isDebugJustStarted,
    // ✨ GESTISCI LE NUOVE PROPRIETÀ NEL copyWith
    bool? isConnectorModeActive,
    String? connectorSourceNodeId,
    Set<String>? selectedConnectorNodeIds,
    bool clearConnectorSource = false, // Utility per resettare il sourceId a null
    Map<String, bool>? decisionSelections,
    ConnectorPurpose? connectorPurpose,
    CallStack? callStack, // 🆕 NUOVO
    Map<String, Flowchart>? projectFlowcharts, // 🆕 NUOVO
  }) {
    return FlowchartLoaded(
      flowchart: flowchart ?? this.flowchart,
      selectedNodeId:
          clearSelection ? null : (selectedNodeId ?? this.selectedNodeId),
      isDebugMode: isDebugMode ?? this.isDebugMode,
      debugPath: debugPath ?? this.debugPath,
      debugIndex: debugIndex ?? this.debugIndex,
      isDebugJustStarted: isDebugJustStarted ?? this.isDebugJustStarted,
      // ✨ GESTISCI LE NUOVE PROPRIETÀ NEL copyWith
      isConnectorModeActive: isConnectorModeActive ?? this.isConnectorModeActive,
      connectorSourceNodeId: clearConnectorSource
          ? null
          : (connectorSourceNodeId ?? this.connectorSourceNodeId),
      selectedConnectorNodeIds:
          selectedConnectorNodeIds ?? this.selectedConnectorNodeIds,
      decisionSelections: decisionSelections ?? this.decisionSelections,
      connectorPurpose: connectorPurpose ?? this.connectorPurpose,
      callStack: callStack ?? this.callStack, // 🆕 NUOVO
      projectFlowcharts: projectFlowcharts ?? this.projectFlowcharts, // 🆕 NUOVO
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
        isDebugJustStarted,
        isConnectorModeActive,
        connectorSourceNodeId,
        selectedConnectorNodeIds,
        decisionSelections,
        connectorPurpose,
        callStack, // 🆕 NUOVO
        projectFlowcharts, // 🆕 NUOVO
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

