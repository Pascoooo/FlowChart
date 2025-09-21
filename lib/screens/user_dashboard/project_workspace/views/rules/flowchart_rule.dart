import '../../../../../blocs/flowchart_bloc/flowchart_state.dart';

abstract class FlowchartRule {
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext});
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult.success()
      : isValid = true,
        errorMessage = null;

  ValidationResult.failure(this.errorMessage) : isValid = false;
}

/// REGOLA: Può esistere un solo nodo di tipo 'start'.
class SingleStartNodeRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartShape) return ValidationResult.success();
    final newShape = actionContext;

    if (newShape.type == 'start') {
      final hasExistingStartNode = state.shapes.any((s) => s.type == 'start');
      if (hasExistingStartNode) {
        return ValidationResult.failure("Esiste già un nodo 'Inizio'.");
      }
    }
    return ValidationResult.success();
  }
}

/// REGOLA: Può esistere un solo nodo di tipo 'fine'.
class SingleEndNodeRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartShape) return ValidationResult.success();
    final newShape = actionContext;

    if (newShape.type == 'fine') {
      final hasExistingEndNode = state.shapes.any((s) => s.type == 'fine');
      if (hasExistingEndNode) {
        return ValidationResult.failure("Un nodo 'Fine' esiste già.");
      }
    }
    return ValidationResult.success();
  }
}

/// REGOLA: Gestisce i vincoli sulle connessioni in entrata.
class IncomingConnectionRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartConnection) return ValidationResult.success();
    final newConnection = actionContext;

    FlowchartShape toShape;
    try {
      toShape = state.shapes.firstWhere((s) => s.id == newConnection.toShapeId);
    } catch (e) {
      return ValidationResult.success();
    }

    // Un nodo 'fine' può ricevere connessioni illimitate
    if (toShape.type == 'fine') {
      return ValidationResult.success();
    }

    if (toShape.incomingConnectionIds.length >= toShape.maxIncomingConnections) {
      if (toShape.type == 'start') {
        return ValidationResult.failure("Il nodo 'Inizio' non può avere connessioni in entrata.");
      }
      return ValidationResult.failure("Questa forma ha già raggiunto il numero massimo di connessioni in entrata.");
    }

    return ValidationResult.success();
  }
}

/// REGOLA: Gestisce i vincoli sulle connessioni in uscita.
class OutgoingConnectionRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartConnection) return ValidationResult.success();
    final newConnection = actionContext;

    FlowchartShape fromShape;
    try {
      fromShape = state.shapes.firstWhere((s) => s.id == newConnection.fromShapeId);
    } catch (e) {
      return ValidationResult.failure("La forma di partenza della connessione non è valida.");
    }

    // Logica efficiente: controlla direttamente le proprietà della forma.
    if (fromShape.outgoingConnectionIds.length >= fromShape.maxOutgoingConnections) {
      if (fromShape.type == 'fine') {
        return ValidationResult.failure("Il nodo 'Fine' non può avere connessioni in uscita.");
      }
      if (fromShape.type == 'condizione') {
        return ValidationResult.failure("Un nodo 'Condizione' non può avere più di due uscite.");
      }
      return ValidationResult.failure("Questa forma ha già raggiunto il numero massimo di connessioni in uscita.");
    }

    return ValidationResult.success();
  }
}

/// REGOLA: Impedisce doppie connessioni sullo stesso ramo (true/false) di un nodo condizione.
class DecisionPortUniquenessRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartConnection) return ValidationResult.success();
    final newConn = actionContext;
    if (newConn.fromPort == null) return ValidationResult.success();
    FlowchartShape? fromShape;
    try { fromShape = state.shapes.firstWhere((s) => s.id == newConn.fromShapeId); } catch (_) {}
    if (fromShape == null || fromShape.type != 'condizione') return ValidationResult.success();

    final duplicate = state.connections.any((c) => c.fromShapeId == newConn.fromShapeId && c.fromPort == newConn.fromPort);
    if (duplicate) {
      return ValidationResult.failure("Il ramo '${newConn.fromPort}' è già occupato.");
    }
    return ValidationResult.success();
  }
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
      final result = rule.validate(state, actionContext: actionContext);
      if (!result.isValid) {
        return result; // Si ferma alla prima regola violata
      }
    }
    return ValidationResult.success(); // Tutto ok
  }
}