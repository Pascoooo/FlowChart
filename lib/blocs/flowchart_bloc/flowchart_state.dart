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
enum ConnectorPurpose { normal, doWhileBody, resetFromNode, loopClosure }

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

  // ✨ PROPRIETÀ PER LA MODALITÀ CONNETTORE
  final bool isConnectorModeActive;
  final String? connectorSourceNodeId;
  final Set<String> selectedConnectorNodeIds;
  final ConnectorPurpose? connectorPurpose;

  // 🆕 Tutti i flowchart del progetto (per riferimenti)
  final Map<String, Flowchart> projectFlowcharts;

  // 🟠 FIX MAGGIORE #7: Flag per bloccare editing durante debug
  final bool isDebugMode;

  static const _uuid = Uuid();

  const FlowchartLoaded({
    required this.flowchart,
    this.selectedNodeId,
    this.isConnectorModeActive = false,
    this.connectorSourceNodeId,
    this.selectedConnectorNodeIds = const {},
    this.connectorPurpose,
    this.projectFlowcharts = const {},
    this.isDebugMode = false,
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

  /// Restituisce gli ID dei nodi do-while che non hanno ancora il collegamento di inizio corpo ('true' o legacy 'doWhileStart').
  List<String> unresolvedDoWhileIds() {
    final ids = <String>[];
    for (final n in flowchart.nodes) {
      if (n.kind != FlowNodeKind.doWhileLoop) continue;
      final hasBody = flowchart.edges.any((e) => e.from == n.id && (e.port == 'true' || e.port == 'doWhileStart'));
      if (!hasBody) ids.add(n.id);
    }
    return ids;
  }

  /// Verifica se esistono candidati validi per l'inizio del corpo di un do-while.
  /// Candidati: nodi che possono raggiungere il do-while, esclusi Start e il do-while stesso.
  bool hasEligibleDoWhileBodyCandidates(String doWhileNodeId) {
    final candidates = nodesThatCanReach(doWhileNodeId)
      ..removeWhere((id) {
        final n = getNodeById(id);
        return n == null || n.kind == FlowNodeKind.start || id == doWhileNodeId;
      });
    return candidates.isNotEmpty;
  }

  /// Trova l'arco 'true' del while (inizio del corpo), se presente.
  FlowchartEdge? getWhileTrueEdge(String whileNodeId) {
    try {
      return flowchart.edges.firstWhere((e) => e.from == whileNodeId && e.port == 'true');
    } catch (_) {
      return null;
    }
  }

  /// Calcola i nodi del corpo del while: BFS a partire dall'edge 'true', ignorando archi 'loop'.
  Set<String> whileBodyNodes(String whileNodeId) {
    final startEdge = getWhileTrueEdge(whileNodeId);
    if (startEdge == null) return <String>{};

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
    return visited;
  }

  /// Verifica se esiste almeno un arco di chiusura del while (port 'loop') da un nodo del corpo verso il while.
  bool whileHasLoopClosure(String whileNodeId) {
    final body = whileBodyNodes(whileNodeId);
    if (body.isEmpty) return false;
    return flowchart.edges.any((e) => e.port == 'loop' && e.to == whileNodeId && body.contains(e.from));
  }

  /// 🆕 NUOVO: Restituisce gli ID dei nodi foglia all'interno del corpo di un ciclo
  /// Un nodo foglia è un nodo senza archi in uscita (esclusi archi 'loop')
  List<String> getLoopBodyLeafNodes(String loopNodeId) {
    final loopNode = getNodeById(loopNodeId);
    if (loopNode == null) return [];

    Set<String> bodyNodes;
    if (loopNode.kind == FlowNodeKind.whileLoop) {
      bodyNodes = whileBodyNodes(loopNodeId);
    } else if (loopNode.kind == FlowNodeKind.doWhileLoop) {
      bodyNodes = doWhileBodyNodes(loopNodeId);
    } else {
      return [];
    }

    // Trova i nodi foglia: nodi del corpo che non hanno archi in uscita (esclusi 'loop')
    final leafNodes = <String>[];
    for (final nodeId in bodyNodes) {
      final outgoing = flowchart.edges.where((e) => e.from == nodeId && e.port != 'loop').toList();
      if (outgoing.isEmpty) {
        leafNodes.add(nodeId);
      }
    }

    return leafNodes;
  }

  /// 🆕 NUOVO: Verifica se un ciclo ha più di un nodo foglia e quindi richiede la modalità connettore
  bool loopRequiresClosureMode(String loopNodeId) {
    final leafNodes = getLoopBodyLeafNodes(loopNodeId);
    return leafNodes.length >= 2;
  }

  /// 🆕 NUOVO: Verifica se un nodo può essere selezionato nella modalità loop closure
  /// (deve essere un nodo foglia all'interno del ciclo)
  bool canSelectForLoopClosure(String nodeId, String loopNodeId) {
    final leafNodes = getLoopBodyLeafNodes(loopNodeId);
    return leafNodes.contains(nodeId);
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
    bool? isConnectorModeActive,
    String? connectorSourceNodeId,
    Set<String>? selectedConnectorNodeIds,
    ConnectorPurpose? connectorPurpose,
    Map<String, Flowchart>? projectFlowcharts,
    bool? isDebugMode,
    bool clearSelection = false,
    bool clearConnectorSource = false,
  }) {
    return FlowchartLoaded(
      flowchart: flowchart ?? this.flowchart,
      selectedNodeId: clearSelection ? null : (selectedNodeId ?? this.selectedNodeId),
      isConnectorModeActive: isConnectorModeActive ?? this.isConnectorModeActive,
      connectorSourceNodeId: clearConnectorSource ? null : (connectorSourceNodeId ?? this.connectorSourceNodeId),
      selectedConnectorNodeIds: selectedConnectorNodeIds ?? this.selectedConnectorNodeIds,
      connectorPurpose: connectorPurpose ?? this.connectorPurpose,
      projectFlowcharts: projectFlowcharts ?? this.projectFlowcharts,
      isDebugMode: isDebugMode ?? this.isDebugMode,
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
        isConnectorModeActive,
        connectorSourceNodeId,
        selectedConnectorNodeIds,
        connectorPurpose,
        projectFlowcharts,
        isDebugMode,
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
