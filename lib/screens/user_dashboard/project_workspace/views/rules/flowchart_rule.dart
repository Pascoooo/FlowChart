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
      if (fromNode.kind == FlowNodeKind.decision ||
          fromNode.kind == FlowNodeKind.whileLoop ||
          fromNode.kind == FlowNodeKind.doWhileLoop) {
        return ValidationResult.failure("Un nodo condizionale/ciclo non può avere più di due uscite.");
      }
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

    // Il nodo 'Start' non può avere connessioni in entrata.
    if (toNode.kind == FlowNodeKind.start) {
      return ValidationResult.failure("Il nodo 'Inizio' non può avere connessioni in entrata.");
    }

    // RIMOSSO il limite di 1 ingresso per permettere cicli e join.
    // Tutti i nodi (eccetto Start) possono avere ingressi multipli.
    return ValidationResult.success();
  }
}

/// REGOLA: Impedisce di collegare due volte lo stesso ramo (true/false) di un DecisionNode/WhileNode/DoWhileNode.
class DecisionPortUniquenessRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, Object actionContext) {
    if (actionContext is! FlowchartEdge || actionContext.port == null) {
      return ValidationResult.success();
    }

    final fromNode = state.getNodeById(actionContext.from);
    if (fromNode == null) return ValidationResult.success();

    // Applica la regola a Decision, While e DoWhile
    if (fromNode.kind != FlowNodeKind.decision &&
        fromNode.kind != FlowNodeKind.whileLoop &&
        fromNode.kind != FlowNodeKind.doWhileLoop) {
      return ValidationResult.success();
    }

    // Normalizza le porte: nel do-while 'doWhileStart' è equivalente a 'true'
    String _normalized(String? port) {
      if (port == null) return '';
      if (fromNode.kind == FlowNodeKind.doWhileLoop && port == 'doWhileStart') {
        return 'true';
      }
      return port;
    }

    final newPort = _normalized(actionContext.port);

    final hasSamePortAlready = state.flowchart.edges.any(
      (e) => e.from == actionContext.from && _normalized(e.port) == newPort,
    );

    if (hasSamePortAlready) {
      // Messaggio chiaro per l'utente
      final label = newPort == 'true'
          ? "vero"
          : (newPort == 'false' ? "falso" : newPort);
      return ValidationResult.failure(
          "Il ramo '$label' è già collegato per questo nodo.");
    }

    return ValidationResult.success();
  }
}
