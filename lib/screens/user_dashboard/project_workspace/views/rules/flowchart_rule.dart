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


class SingleStartNodeRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartShape) return ValidationResult.success();
    final newShape = actionContext;

    if (newShape.id.toLowerCase().startsWith('start')) {
      final startNodes = state.shapes
          .where((shape) => shape.id.toLowerCase().startsWith('start'))
          .toList();
      if (startNodes.isNotEmpty) {
        return ValidationResult.failure("Esiste già un nodo di inizio.");
      }
    }
    return ValidationResult.success();
  }
}


class SingleEndNodeRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartShape) return ValidationResult.success();
    final newShape = actionContext;

    if (newShape.text.toLowerCase().contains('fine')) {
      final hasExistingEndNode = state.shapes.any(
              (shape) => shape.type == 'circle' && shape.text.toLowerCase().contains('fine')
      );
      if (hasExistingEndNode) {
        return ValidationResult.failure("Un nodo 'Fine' esiste già.");
      }
    }
    return ValidationResult.success();
  }
}

class IncomingConnectionRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    if (actionContext is! FlowchartConnection) return ValidationResult.success();
    final newConnection = actionContext;

    final toShape = state.shapes.firstWhere((s) => s.id == newConnection.toShapeId);
    final existingIncomingCount = state.connections.where((c) => c.toShapeId == toShape.id).length;

    // Caso 1: Il nodo "Inizio" non può avere NESSUNA connessione in entrata.
    if (toShape.text.toLowerCase().contains('inizio')) {
      return ValidationResult.failure("Il nodo 'Inizio' non può avere connessioni in entrata.");
    }

    // Caso 2: Un nodo "Decisione" può avere UNA sola connessione in entrata.
    // (Questa rientra nella regola generale)

    // Caso 3: Tutte le forme (inclusa la Decisione) possono avere al massimo UNA connessione in entrata.
    if (existingIncomingCount >= 1) {
      return ValidationResult.failure("Questa forma ha già una connessione in entrata.");
    }

    return ValidationResult.success();
  }
}

class OutgoingConnectionRule extends FlowchartRule {
  @override
  ValidationResult validate(FlowchartLoaded state, {Object? actionContext}) {
    // La regola si applica solo quando stiamo per creare una nuova connessione.
    if (actionContext is! FlowchartConnection) return ValidationResult.success();
    final newConnection = actionContext;

    final fromShape = state.shapes.firstWhere((s) => s.id == newConnection.fromShapeId);
    final existingOutgoingCount = state.connections.where((c) => c.fromShapeId == fromShape.id).length;

    // Caso 1: Il nodo "Fine" non può avere NESSUNA connessione in uscita.
    if (fromShape.text.toLowerCase().contains('fine')) {
      return ValidationResult.failure("Il nodo 'Fine' non può avere connessioni in uscita.");
    }

    // Caso 2: Il nodo "Decisione" può avere al massimo DUE connessioni in uscita.
    if (fromShape.type == 'diamond') {
      if (existingOutgoingCount >= 2) {
        return ValidationResult.failure("Un nodo 'Decisione' non può avere più di due uscite.");
      }
      return ValidationResult.success();
    }

    // Caso 3: Tutte le altre forme possono avere al massimo UNA connessione in uscita.
    if (existingOutgoingCount >= 1) {
      return ValidationResult.failure("Questa forma ha già una connessione in uscita.");
    }

    return ValidationResult.success();
  }
}

class FlowchartValidator {
  final _rules = [
    // Regole sulla topologia generale del diagramma
    SingleStartNodeRule(),
    SingleEndNodeRule(),

    // Regole sulle connessioni tra le forme
    OutgoingConnectionRule(),
    IncomingConnectionRule(),
  ];

  ValidationResult validate(FlowchartLoaded state, Object actionContext) {
    for (final rule in _rules) {
      final result = rule.validate(state, actionContext: actionContext);
      if (!result.isValid) {
        return result;
      }
    }
    return ValidationResult.success();
  }
}