/// Servizio centralizzato per la validazione dei flowchart.
/// Unifica validazione real-time (durante editing) e validazione progetto completo.
/// Permette validazione on-demand tramite bottone BUILD invece di validazione continua.
import 'package:flowchart_repository/flowchart_repository.dart';
import '../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../screens/user_dashboard/project_workspace/views/rules/flowchart_rule.dart';

/// Report di validazione contenente errori e warning.
/// Usato per mostrare i risultati della validazione all'utente.
class ValidationReport {
  final List<String> errors;
  final List<String> warnings;

  bool get isValid => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  ValidationReport({required this.errors, required this.warnings});

  ValidationReport.success() : errors = const [], warnings = const [];
}

/// Servizio centralizzato per validazione flowchart.
/// Espone metodi per validazione singola azione e validazione progetto completo.
class FlowchartValidationService {
  static final _validator = FlowchartValidator();

  /// Valida una singola azione (aggiunta nodo, edge, ecc.) durante l'editing.
  /// Usato da FlowchartBloc per validare operazioni in tempo reale.
  static ValidationResult validateAction(FlowchartLoaded state, Object action) {
    return _validator.validate(state, action);
  }

  /// Valida un flowchart completo verificando correttezza strutturale.
  /// Chiamato dal FileSystemBloc quando l'utente clicca BUILD.
  /// Restituisce un report con errori e warning dettagliati.
  static ValidationReport validateCompleteFlowchart(Flowchart flowchart) {
    final errors = <String>[];
    final warnings = <String>[];

    // VALIDAZIONE 1: Nodo di partenza obbligatorio
    final startNode = flowchart.nodes.where((n) =>
      n.kind == FlowNodeKind.start || n.kind == FlowNodeKind.functionHeader
    ).firstOrNull;

    if (startNode == null) {
      errors.add("Flowchart '${flowchart.name}': Manca il nodo di inizio");
      return ValidationReport(errors: errors, warnings: warnings);
    }

    // VALIDAZIONE 2: Raggiungibilità nodi
    final reachable = _findReachableNodes(flowchart, startNode.id);
    final unreachableNodes = flowchart.nodes.where((n) => !reachable.contains(n.id));
    if (unreachableNodes.isNotEmpty) {
      for (final node in unreachableNodes) {
        warnings.add("Flowchart '${flowchart.name}': Nodo '${node.text}' non raggiungibile");
      }
    }

    // VALIDAZIONE 3: Nodi senza uscite (esclusi nodi terminali)
    for (final node in flowchart.nodes) {
      if (node.kind == FlowNodeKind.end || node.kind == FlowNodeKind.returnNode) {
        continue; // Nodi terminali: OK senza uscite
      }

      final hasOutgoing = flowchart.edges.any((e) => e.from == node.id);
      if (!hasOutgoing && reachable.contains(node.id)) {
        errors.add("Flowchart '${flowchart.name}': Nodo '${node.text}' è una foglia senza uscite (aggiungi connessione o elimina il nodo)");
      }
    }

    // VALIDAZIONE 4: Cicli while senza chiusura
    for (final node in flowchart.nodes) {
      if (node.kind == FlowNodeKind.whileLoop) {
        final hasLoopClosure = flowchart.edges.any((e) =>
          e.to == node.id && e.port == 'loop'
        );
        if (!hasLoopClosure) {
          warnings.add("Flowchart '${flowchart.name}': Ciclo while '${node.text}' senza chiusura (usa il connettore per chiudere il ciclo)");
        }
      }
    }

    // VALIDAZIONE 5: Nodi condizionali con rami incompleti
    for (final node in flowchart.nodes) {
      if (node.kind == FlowNodeKind.decision ||
          node.kind == FlowNodeKind.whileLoop ||
          node.kind == FlowNodeKind.doWhileLoop) {

        final outgoingEdges = flowchart.edges.where((e) => e.from == node.id);
        final hasTrueBranch = outgoingEdges.any((e) => e.port == 'true' || e.port == 'doWhileStart');
        final hasFalseBranch = outgoingEdges.any((e) => e.port == 'false');

        if (!hasTrueBranch) {
          errors.add("Flowchart '${flowchart.name}': Nodo '${node.text}' manca il ramo VERO");
        }
        if (!hasFalseBranch) {
          errors.add("Flowchart '${flowchart.name}': Nodo '${node.text}' manca il ramo FALSO");
        }
      }
    }

    // VALIDAZIONE 6: Flowchart di tipo function deve avere almeno un nodo Return
    if (flowchart.type == FlowchartType.function) {
      final hasReturn = flowchart.nodes.any((n) => n.kind == FlowNodeKind.returnNode);
      if (!hasReturn && flowchart.signature.returnType != 'void') {
        errors.add("Flowchart '${flowchart.name}': Funzione con return type '${flowchart.signature.returnType}' deve avere almeno un nodo Return");
      }
    }

    return ValidationReport(errors: errors, warnings: warnings);
  }

  /// Trova tutti i nodi raggiungibili dal nodo di partenza tramite BFS.
  /// Ritorna un Set con gli ID dei nodi raggiungibili.
  static Set<String> _findReachableNodes(Flowchart fc, String startId) {
    final visited = <String>{};
    final queue = [startId];

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (!visited.add(cur)) continue;

      for (final e in fc.edges.where((e) => e.from == cur)) {
        queue.add(e.to);
      }
    }

    return visited;
  }
}
