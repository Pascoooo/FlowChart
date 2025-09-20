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

/// REGOLA: Può esistere un solo nodo di tipo 'end'.
class SingleEndNodeRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartShape) return ValidationResult.success();
    final newShape = actionContext;

    if (newShape.type == 'end') {
      final hasExistingEndNode = state.shapes.any((s) => s.type == 'end');
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
      // Cerca la forma di destinazione. Se non esiste, è la forma che stiamo per aggiungere,
      // quindi la regola non si applica ancora a lei.
      toShape = state.shapes.firstWhere((s) => s.id == newConnection.toShapeId);
    } catch (e) {
      // La forma non è stata trovata, significa che è la nuova forma.
      // Per definizione ha 0 connessioni in entrata, quindi la regola è valida.
      return ValidationResult.success();
    }

    // Logica efficiente: controlla direttamente le proprietà della forma.
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
      if (fromShape.type == 'end') {
        return ValidationResult.failure("Il nodo 'Fine' non può avere connessioni in uscita.");
      }
      if (fromShape.type == 'decision') {
        return ValidationResult.failure("Un nodo 'Decisione' non può avere più di due uscite.");
      }
      return ValidationResult.failure("Questa forma ha già raggiunto il numero massimo di connessioni in uscita.");
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