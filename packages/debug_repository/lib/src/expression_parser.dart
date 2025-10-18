// file: lib/config/services/expression_parser.dart

import 'dart:math' as math;
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:math_expressions/math_expressions.dart';

/// Parser e valutatore unificato per le espressioni.
///
/// NOVITÀ: Ora supporta type checking per le assegnazioni.
class ExpressionParser {
  /// Valuta un'espressione e VALIDA il tipo del risultato
  ///
  /// [expression] - L'espressione da valutare
  /// [variables] - Variabili disponibili con i loro valori
  /// [targetDeclaration] - Dichiarazione della variabile target (opzionale, per type checking)
  ///
  /// Ritorna ExpressionResult con isValid = false se il tipo non corrisponde
  static ExpressionResult evaluate(
      String expression,
      Map<String, dynamic> variables, {
        VariableDeclaration? targetDeclaration,
      }) {
    try {
      final trimmed = expression.trim();

      if (trimmed.isEmpty) {
        return const ExpressionResult(isValid: true, value: '');
      }

      // Normalizza: {var} → var
      final normalized = trimmed.replaceAll(RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}'), r'$1');

      // Stringhe quotate
      final isDoubleQuoted = normalized.startsWith('"') && normalized.endsWith('"');
      final isSingleQuoted = normalized.startsWith("'") && normalized.endsWith("'");
      if (isDoubleQuoted || isSingleQuoted) {
        final inner = normalized.substring(1, normalized.length - 1);
        final unescaped = isDoubleQuoted ? inner.replaceAll('\\"', '"') : inner.replaceAll("\\'", "'");

        // Type check: se target è int/double, stringa non è compatibile
        if (targetDeclaration != null) {
          final typeError = _checkTypeCompatibility('string', targetDeclaration.dataType);
          if (typeError != null) {
            return ExpressionResult(isValid: false, errorMessage: typeError);
          }
        }

        return ExpressionResult(isValid: true, value: unescaped);
      }

      // Singolo identificatore: restituisci valore dalla mappa
      final singleIdentRegex = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
      if (singleIdentRegex.hasMatch(normalized)) {
        if (variables.containsKey(normalized)) {
          final value = variables[normalized];

          // Type check: il valore della variabile sorgente è compatibile col target?
          if (targetDeclaration != null && value != null) {
            final sourceType = _getValueType(value);
            final typeError = _checkTypeCompatibility(sourceType, targetDeclaration.dataType);
            if (typeError != null) {
              return ExpressionResult(isValid: false, errorMessage: typeError);
            }
          }

          return ExpressionResult(isValid: true, value: value);
        }
      }

      // Numeri puri
      final numValue = num.tryParse(normalized);
      if (numValue != null) {
        // Type check per numeri
        if (targetDeclaration != null) {
          final isInt = numValue == numValue.toInt();
          final sourceType = isInt ? 'int' : 'double';
          final typeError = _checkTypeCompatibility(sourceType, targetDeclaration.dataType);
          if (typeError != null) {
            return ExpressionResult(isValid: false, errorMessage: typeError);
          }
        }

        return ExpressionResult(isValid: true, value: numValue);
      }

      // Letterali booleani
      if (normalized == 'true') {
        if (targetDeclaration != null) {
          final typeError = _checkTypeCompatibility('bool', targetDeclaration.dataType);
          if (typeError != null) {
            return ExpressionResult(isValid: false, errorMessage: typeError);
          }
        }
        return const ExpressionResult(isValid: true, value: true);
      }
      if (normalized == 'false') {
        if (targetDeclaration != null) {
          final typeError = _checkTypeCompatibility('bool', targetDeclaration.dataType);
          if (typeError != null) {
            return ExpressionResult(isValid: false, errorMessage: typeError);
          }
        }
        return const ExpressionResult(isValid: true, value: false);
      }

      // Costanti matematiche
      if (normalized == 'pi') {
        if (targetDeclaration != null) {
          final typeError = _checkTypeCompatibility('double', targetDeclaration.dataType);
          if (typeError != null) {
            return ExpressionResult(isValid: false, errorMessage: typeError);
          }
        }
        return ExpressionResult(isValid: true, value: math.pi);
      }
      if (normalized == 'e') {
        if (targetDeclaration != null) {
          final typeError = _checkTypeCompatibility('double', targetDeclaration.dataType);
          if (typeError != null) {
            return ExpressionResult(isValid: false, errorMessage: typeError);
          }
        }
        return ExpressionResult(isValid: true, value: math.e);
      }

      // Espressioni matematiche
      final hasMathOps = RegExp(r'[+\-*/%^()]').hasMatch(normalized);
      if (!hasMathOps) {
        // Stringa non quotata senza operatori
        return const ExpressionResult(
          isValid: false,
          errorMessage: 'Stringa non quotata. Usa "..." per le stringhe.',
        );
      }

      // Estrai variabili dall'espressione
      final idRegex = RegExp(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b');
      final idents = { for (final m in idRegex.allMatches(normalized)) m.group(0)! };

      const allowedLiterals = {'true', 'false', 'pi', 'e'};
      const allowedFuncs = {
        'sin', 'cos', 'tan', 'sqrt', 'log', 'ln', 'exp', 'abs', 'ceil', 'floor', 'round', 'min', 'max', 'pow'
      };

      final usedVars = idents.where((i) =>
      !allowedLiterals.contains(i) && !allowedFuncs.contains(i)
      ).toList();

      // Valida che tutte le variabili existano
      for (final v in usedVars) {
        if (!variables.containsKey(v)) {
          return ExpressionResult(isValid: false, errorMessage: 'Variabile "$v" non trovata');
        }
      }

      // Prepara contesto di valutazione
      final cm = ContextModel();
      for (final v in usedVars) {
        final val = variables[v];
        if (val is num) {
          cm.bindVariable(Variable(v), Number(val.toDouble()));
        } else if (val is bool) {
          cm.bindVariable(Variable(v), Number(val ? 1.0 : 0.0));
        } else if (val == null) {
          cm.bindVariable(Variable(v), Number(0.0));
        } else {
          return ExpressionResult(
            isValid: false,
            errorMessage: 'Variabile "$v" non numerica, non può usarla in espressione matematica',
          );
        }
      }

      // Valuta l'espressione
      try {
        final parser = GrammarParser();
        final exp = parser.parse(normalized);
        final evaluator = RealEvaluator(cm);
        final result = evaluator.evaluate(exp);

        // Type check sul risultato
        if (targetDeclaration != null) {
          final resultType = result == result.toInt() ? 'int' : 'double';
          final typeError = _checkTypeCompatibility(resultType, targetDeclaration.dataType);
          if (typeError != null) {
            return ExpressionResult(isValid: false, errorMessage: typeError);
          }
        }

        if (result == result.toInt()) {
          return ExpressionResult(isValid: true, value: result.toInt());
        }
        return ExpressionResult(isValid: true, value: result);
      } catch (e) {
        return ExpressionResult(isValid: false, errorMessage: 'Errore: ${e.toString()}');
      }
    } catch (e) {
      return ExpressionResult(isValid: false, errorMessage: 'Errore valutazione: ${e.toString()}');
    }
  }

  // ============================================================================
  // 🔴 TYPE CHECKING - NUOVO SISTEMA
  // ============================================================================

  /// Verifica la compatibilità tra tipo sorgente e tipo target
  ///
  /// Ritorna null se compatibile, altrimenti il messaggio di errore
  static String? _checkTypeCompatibility(String sourceType, String targetType) {
    final source = sourceType.toLowerCase();
    final target = targetType.toLowerCase();

    // Se sono lo stesso tipo: OK
    if (source == target) return null;

    // Sinonimi accettati
    const intTypes = {'int', 'integer'};
    const doubleTypes = {'double', 'float', 'number'};
    const boolTypes = {'bool', 'boolean'};
    const stringTypes = {'string', 'str', 'text'};

    final sourceCategory = _getTypeCategory(source);
    final targetCategory = _getTypeCategory(target);

    // Se categorie diverse: errore
    if (sourceCategory != targetCategory) {
      return 'Tipo incompatibile: tentativo di assegnare $source a $target';
    }

    // Conversioni permesse entro la stessa categoria
    if (sourceCategory == 'numeric') {
      // int → double: OK (allargamento)
      if (intTypes.contains(source) && doubleTypes.contains(target)) {
        return null;
      }
      // double → int: ERRORE (restringimento, potrebbe perdere dati)
      if (doubleTypes.contains(source) && intTypes.contains(target)) {
        return 'Conversione non permessa: $source → $target (perdita di precisione)';
      }
    }

    return null;
  }

  /// Determina la categoria di tipo (numeric, bool, string)
  static String _getTypeCategory(String type) {
    const intTypes = {'int', 'integer'};
    const doubleTypes = {'double', 'float', 'number'};
    const boolTypes = {'bool', 'boolean'};

    if (intTypes.contains(type)) return 'numeric';
    if (doubleTypes.contains(type)) return 'numeric';
    if (boolTypes.contains(type)) return 'bool';
    return 'string';
  }

  /// Inferisce il tipo di un valore runtime
  static String _getValueType(dynamic value) {
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is String) return 'string';
    return 'unknown';
  }

  /// Valida un'espressione senza valutarla
  static ValidationResult validate(String expression, List<String> availableVariables) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      return const ValidationResult(isValid: false, errorMessage: 'Espressione vuota');
    }

    try {
      final normalized = trimmed.replaceAll(RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}'), r'$1');

      // Stringhe quotate: sempre valide
      final isDoubleQuoted = normalized.startsWith('"') && normalized.endsWith('"');
      final isSingleQuoted = normalized.startsWith("'") && normalized.endsWith("'");
      if (isDoubleQuoted || isSingleQuoted) {
        return const ValidationResult(isValid: true);
      }

      // Estrai identificatori
      final idRegex = RegExp(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b');
      final idents = { for (final m in idRegex.allMatches(normalized)) m.group(0)! };

      const allowedLiterals = {'true', 'false', 'pi', 'e'};
      const allowedFuncs = {
        'sin', 'cos', 'tan', 'sqrt', 'log', 'ln', 'exp', 'abs', 'ceil', 'floor', 'round', 'min', 'max', 'pow'
      };

      // Verifica che gli identificatori siano validi
      for (final ident in idents) {
        if (allowedLiterals.contains(ident)) continue;
        if (allowedFuncs.contains(ident)) continue;
        if (!availableVariables.contains(ident)) {
          return ValidationResult(
            isValid: false,
            errorMessage: 'Variabile "$ident" non trovata',
          );
        }
      }

      // Prova a parsare
      try {
        final parser = GrammarParser();
        parser.parse(normalized);
        return const ValidationResult(isValid: true);
      } catch (e) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Espressione non valida: ${e.toString()}',
        );
      }
    } catch (e) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Errore di validazione: ${e.toString()}',
      );
    }
  }

  static List<String> getUsedVariables(String expression) {
    final regex = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    final matches = regex.allMatches(expression);
    return matches.map((m) => m.group(1)!).toList();
  }

  static bool isLiteral(String expression) {
    return !expression.contains('{') && !expression.contains('}');
  }

  static bool isSimpleVariableReference(String expression) {
    final trimmed = expression.trim();
    final regex = RegExp(r'^\{([a-zA-Z_][a-zA-Z0-9_]*)\}$');
    return regex.hasMatch(trimmed);
  }
}

/// Risultato della validazione
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}

/// Risultato della valutazione (ora con type checking)
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