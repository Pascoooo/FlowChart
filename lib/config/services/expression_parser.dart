// file: lib/config/services/expression_parser.dart
import 'package:math_expressions/math_expressions.dart';

/// Parser e valutatore unificato per le espressioni.
///
/// Sintassi:
/// - Usa {variabile} per riferirsi al valore di una variabile
/// - Esempio: "{x} + 10 * {y}" -> sostituisce {x} e {y} con i loro valori
/// - Stringhe normali senza graffe sono considerate letterali
class ExpressionParser {
  /// Valida un'espressione e restituisce un risultato con eventuali errori.
  ///
  /// [expression] - L'espressione da validare
  /// [availableVariables] - Lista dei nomi delle variabili disponibili
  static ValidationResult validate(String expression, List<String> availableVariables) {
    if (expression.trim().isEmpty) {
      return const ValidationResult(isValid: false, errorMessage: 'Espressione vuota');
    }

    try {
      // Estrai tutti i riferimenti alle variabili {nome}
      final variableReferences = _extractVariableReferences(expression);

      // Verifica che tutte le variabili referenziate esistano
      for (final varName in variableReferences) {
        if (!availableVariables.contains(varName)) {
          return ValidationResult(
            isValid: false,
            errorMessage: 'Variabile "{$varName}" non trovata',
          );
        }
      }

      // Verifica che le parentesi graffe siano bilanciate
      if (!_areBalancedBraces(expression)) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Parentesi graffe non bilanciate',
        );
      }

      // Se l'espressione contiene identificatori fuori dalle graffe, rifiuta
      // Rimuovi prima i riferimenti {var} e i numeri (anche notazione scientifica),
      // poi verifica se restano lettere (identificatori nudi)
      String withoutBraces = expression.replaceAll(RegExp(r'\{[a-zA-Z_][a-zA-Z0-9_]*\}'), '');
      // rimuovi numeri interi/decimali/opzione esponente
      withoutBraces = withoutBraces.replaceAll(
          RegExp(r'(?<![A-Za-z_])[+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?'),
          '');
      // rimuovi spazi, operatori e punteggiatura comuni
      final leftoverLetters = withoutBraces.replaceAll(RegExp(r'[^A-Za-z_]'), '');
      if (leftoverLetters.isNotEmpty) {
        return ValidationResult(
          isValid: false,
          errorMessage:
              'Usa le graffe per le variabili (es.: {x}). Identificatori non validi trovati.',
        );
      }

      // Se l'espressione contiene solo una variabile, è valida
      final trimmed = expression.trim();
      if (variableReferences.length == 1 && trimmed == '{${variableReferences.first}}') {
        return ValidationResult(isValid: true);
      }

      // Se è un valore letterale (numero o stringa), è valida
      if (!expression.contains('{') && !expression.contains('}')) {
        // Verifica se è un numero
        if (num.tryParse(expression.trim()) != null) {
          return ValidationResult(isValid: true);
        }
        // Se non è un numero, è considerata una stringa letterale (valida)
        return ValidationResult(isValid: true);
      }

      // Tenta di validare come espressione matematica
      // Sostituisci temporaneamente le variabili con valori numerici per il test
      String testExpression = expression;
      for (final varName in variableReferences) {
        testExpression = testExpression.replaceAll('{$varName}', '1');
      }

      // Prova a parsare l'espressione
      try {
        final parser = GrammarParser();
        parser.parse(testExpression);
        return ValidationResult(isValid: true);
      } catch (e) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Espressione matematica non valida: ${e.toString()}',
        );
      }
    } catch (e) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Errore di validazione: ${e.toString()}',
      );
    }
  }

  /// Valuta un'espressione sostituendo le variabili con i loro valori.
  /// Restituisce un risultato con stato e valore.
  static ExpressionResult evaluate(String expression, Map<String, dynamic> variables) {
    try {
      final trimmed = expression.trim();

      // Se è vuota, restituisci stringa vuota valida
      if (trimmed.isEmpty) {
        return const ExpressionResult(isValid: true, value: '');
      }

      // Estrai i riferimenti alle variabili
      final variableReferences = _extractVariableReferences(trimmed);

      // Se non ci sono riferimenti a variabili, restituisci il valore letterale
      if (variableReferences.isEmpty) {
        // Prova a parsare come numero
        final numValue = num.tryParse(trimmed);
        if (numValue != null) return ExpressionResult(isValid: true, value: numValue);

        // Altrimenti restituisci come stringa
        return ExpressionResult(isValid: true, value: trimmed);
      }

      // Se l'espressione è solo un riferimento a una singola variabile
      if (variableReferences.length == 1 && trimmed == '{${variableReferences.first}}') {
        final varName = variableReferences.first;
        if (!variables.containsKey(varName)) {
          return ExpressionResult(
            isValid: false,
            errorMessage: 'Variabile "{$varName}" non trovata',
          );
        }
        return ExpressionResult(isValid: true, value: variables[varName]);
      }

      // Sostituisci le variabili con i loro valori
      String processedExpression = trimmed;
      final contextVariables = <Variable, dynamic>{};

      for (final varName in variableReferences) {
        if (!variables.containsKey(varName)) {
          // Variabile mancante -> errore
          return ExpressionResult(
            isValid: false,
            errorMessage: 'Variabile "{$varName}" non trovata',
          );
        }

        final value = variables[varName];
        // Sostituisci {variabile} con il valore
        processedExpression = processedExpression.replaceAll(
          '{$varName}',
          value.toString(),
        );

        // Crea anche una variabile per il parser matematico
        contextVariables[Variable(varName)] = value;
      }

      // Prova a valutare come espressione matematica
      try {
        final parser = GrammarParser();
        final exp = parser.parse(processedExpression);

        // Crea il contesto per la valutazione
        final cm = ContextModel();
        for (final entry in contextVariables.entries) {
          final value = entry.value;
          if (value is num) {
            cm.bindVariable(entry.key, Number(value.toDouble()));
          }
        }

        final evaluator = RealEvaluator(cm);
        final result = evaluator.evaluate(exp);

        // Se il risultato è un intero, restituiscilo come tale
        if (result == result.toInt()) {
          return ExpressionResult(isValid: true, value: result.toInt());
        }
        return ExpressionResult(isValid: true, value: result);
      } catch (e) {
        // Espressione matematica non valida
        return ExpressionResult(
          isValid: false,
          errorMessage: 'Espressione matematica non valida: ${e.toString()}',
        );
      }
    } catch (e) {
      // In caso di errore imprevisto
      return ExpressionResult(
        isValid: false,
        errorMessage: 'Errore valutazione: ${e.toString()}',
      );
    }
  }

  /// Estrae tutti i nomi delle variabili referenziati nell'espressione.
  ///
  /// Cerca pattern {nomeVariabile} e restituisce la lista dei nomi.
  static List<String> _extractVariableReferences(String expression) {
    final regex = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    final matches = regex.allMatches(expression);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// Verifica che le parentesi graffe siano bilanciate nell'espressione.
  static bool _areBalancedBraces(String expression) {
    int count = 0;
    for (int i = 0; i < expression.length; i++) {
      if (expression[i] == '{') {
        count++;
      } else if (expression[i] == '}') {
        count--;
        if (count < 0) return false; // Parentesi chiusa prima di essere aperta
      }
    }
    return count == 0; // Devono essere tutte bilanciate
  }

  /// Ottiene tutte le variabili utilizzate in un'espressione.
  ///
  /// Utile per tracciare le dipendenze tra variabili.
  static List<String> getUsedVariables(String expression) {
    return _extractVariableReferences(expression);
  }

  /// Verifica se un'espressione è un valore letterale (non contiene variabili).
  static bool isLiteral(String expression) {
    return !expression.contains('{') && !expression.contains('}');
  }

  /// Verifica se un'espressione è un semplice riferimento a una variabile.
  /// Esempio: "{x}" restituisce true, "{x} + 1" restituisce false
  static bool isSimpleVariableReference(String expression) {
    final trimmed = expression.trim();
    final regex = RegExp(r'^\{([a-zA-Z_][a-zA-Z0-9_]*)\}$');
    return regex.hasMatch(trimmed);
  }
}

/// Risultato della validazione di un'espressione.
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  @override
  String toString() {
    return isValid
        ? 'Valida'
        : 'Non valida: ${errorMessage ?? "errore sconosciuto"}';
  }
}

/// Risultato della valutazione di un'espressione.
class ExpressionResult {
  final bool isValid;
  final dynamic value;
  final String? errorMessage;

  const ExpressionResult({
    required this.isValid,
    this.value,
    this.errorMessage,
  });
}
