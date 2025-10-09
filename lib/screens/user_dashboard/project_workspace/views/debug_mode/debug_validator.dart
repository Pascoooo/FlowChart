import 'package:flowchart_repository/flowchart_repository.dart';

/// Risultato della validazione runtime di un nodo
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({required this.isValid, this.errorMessage});

  factory ValidationResult.success() =>
      const ValidationResult(isValid: true);

  factory ValidationResult.error(String message) =>
      ValidationResult(isValid: false, errorMessage: message);
}

/// Validatore runtime per nodi del flowchart
class DebugNodeValidator {
  /// Valida un nodo Assignment
  static ValidationResult validateAssignment(
    AssignmentNode node,
    Map<String, dynamic> sessionVars,
  ) {
    if (node.assignments.isEmpty) {
      return ValidationResult.error(
        'Il nodo di assegnazione non contiene operazioni',
      );
    }

    for (final assignment in node.assignments) {
      if (!sessionVars.containsKey(assignment.target)) {
        return ValidationResult.error(
          'Variabile "${assignment.target}" non trovata nelle variabili di sessione',
        );
      }
    }

    return ValidationResult.success();
  }

  /// Valida un nodo Output
  static ValidationResult validateOutput(
    OutputNode node,
    Map<String, dynamic> sessionVars,
  ) {
    if (node.template.isEmpty) {
      return ValidationResult.error('Template di output vuoto');
    }

    for (final variable in node.variables) {
      if (!sessionVars.containsKey(variable.name)) {
        return ValidationResult.error(
          'Variabile "${variable.name}" non trovata nelle variabili di sessione',
        );
      }
    }

    return ValidationResult.success();
  }

  /// Valida un nodo Decision
  static ValidationResult validateDecision(
    DecisionNode node,
    Map<String, dynamic> sessionVars,
  ) {
    if (node.condition.isEmpty) {
      return ValidationResult.error('Condizione vuota');
    }

    // Estrai variabili dalla condizione
    final varPattern = RegExp(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b');
    final matches = varPattern.allMatches(node.condition);

    for (final match in matches) {
      final varName = match.group(1)!;

      // Salta keywords e operatori logici
      if (_isKeywordOrOperator(varName)) continue;

      // Salta numeri
      if (int.tryParse(varName) != null || double.tryParse(varName) != null) {
        continue;
      }

      if (!sessionVars.containsKey(varName)) {
        return ValidationResult.error(
          'Variabile "$varName" nella condizione non trovata',
        );
      }
    }

    return ValidationResult.success();
  }

  /// Controlla se una stringa è una keyword o operatore
  static bool _isKeywordOrOperator(String str) {
    const keywords = {
      'true', 'false', 'and', 'or', 'not',
      'AND', 'OR', 'NOT', 'null',
    };
    return keywords.contains(str);
  }
}

