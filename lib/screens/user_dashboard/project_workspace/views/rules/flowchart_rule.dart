import 'package:flowchart_repository/flowchart_repository.dart';
import '../../../../../blocs/flowchart_bloc/flowchart_state.dart';

/// Risultato di un'operazione di validazione.
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  ValidationResult.success() : isValid = true, errorMessage = null;
  ValidationResult.failure(this.errorMessage) : isValid = false;
}

/// Interfaccia per una singola regola di validazione.
abstract class FlowchartRule {
  ValidationResult validate(FlowchartLoaded state, Object actionContext);
}

/// Il validatore centrale che esegue tutte le regole in sequenza.
class FlowchartValidator {
  final _rules = [
    SingleStartNodeRule(),
    SingleEndNodeRule(),
    OutgoingConnectionRule(),
    IncomingConnectionRule(),
    DecisionPortUniquenessRule(),
  ];

  ValidationResult validate(FlowchartLoaded state, Object actionContext) {
    for (final rule in _rules) {
      final result = rule.validate(state, actionContext);
      if (!result.isValid) {
        return result; // Si ferma alla prima violazione
      }
    }
    return ValidationResult.success();
  }
}

// --- IMPLEMENTAZIONE DELLE REGOLE ---

/// REGOLA: Può esistere un solo nodo Start.
class SingleStartNodeRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, Object actionContext) {
    if (actionContext is FlowNode && actionContext.kind == FlowNodeKind.start) {
      if (state.flowchart.nodes.any((n) => n.kind == FlowNodeKind.start)) {
        return ValidationResult.failure("Può esistere un solo nodo 'Inizio'.");
      }
    }
    return ValidationResult.success();
  }
}

/// REGOLA: Può esistere un solo nodo End.
class SingleEndNodeRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, Object actionContext) {
    if (actionContext is FlowNode && actionContext.kind == FlowNodeKind.end) {
      if (state.flowchart.nodes.any((n) => n.kind == FlowNodeKind.end)) {
        return ValidationResult.failure("Esiste già un nodo 'Fine'.");
      }
    }
    return ValidationResult.success();
  }
}

/// REGOLA: Controlla i limiti sulle connessioni in uscita.
class OutgoingConnectionRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, Object actionContext) {
    if (actionContext is! FlowchartEdge) return ValidationResult.success();

    final fromNode = state.getNodeById(actionContext.from);
    if (fromNode == null) return ValidationResult.success();

    // Utilizziamo l'helper già presente nello state per una logica più pulita
    if (!state.canAddOutgoingConnection(fromNode.id)) {
      if (fromNode.kind == FlowNodeKind.end) return ValidationResult.failure("Il nodo 'Fine' non può avere uscite.");
      if (fromNode.kind == FlowNodeKind.decision) return ValidationResult.failure("Un nodo 'Condizione' non può avere più di due uscite.");
      return ValidationResult.failure("Questo nodo ha già raggiunto il massimo di uscite.");
    }
    return ValidationResult.success();
  }
}

/// REGOLA: Controlla i limiti sulle connessioni in entrata.
class IncomingConnectionRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, Object actionContext) {
    if (actionContext is! FlowchartEdge) return ValidationResult.success();

    final toNode = state.getNodeById(actionContext.to);
    if (toNode == null) return ValidationResult.success();

    if (toNode.kind == FlowNodeKind.start) {
      return ValidationResult.failure("Il nodo 'Inizio' non può avere connessioni in entrata.");
    }

    // Il nodo 'End' può avere ingressi multipli. Per tutti gli altri, il limite è 1.
    if (toNode.kind != FlowNodeKind.end) {
      final incomingCount = state.flowchart.edges.where((e) => e.to == toNode.id).length;
      if (incomingCount >= 1) {
        return ValidationResult.failure("Questo nodo non può avere più di una connessione in entrata.");
      }
    }
    return ValidationResult.success();
  }
}

/// REGOLA: Impedisce di collegare due volte lo stesso ramo (true/false) di un DecisionNode.
class DecisionPortUniquenessRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, Object actionContext) {
    if (actionContext is! FlowchartEdge || actionContext.port == null) return ValidationResult.success();

    final fromNode = state.getNodeById(actionContext.from);
    if (fromNode == null || fromNode.kind != FlowNodeKind.decision) return ValidationResult.success();

    final hasDuplicatePort = state.flowchart.edges.any(
            (e) => e.from == actionContext.from && e.port == actionContext.port
    );

    if (hasDuplicatePort) {
      return ValidationResult.failure("Il ramo '${actionContext.port}' di questo nodo è già collegato.");
    }
    return ValidationResult.success();
  }
}