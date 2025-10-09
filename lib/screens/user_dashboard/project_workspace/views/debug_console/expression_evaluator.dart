import 'package:math_expressions/math_expressions.dart';

/// Valutatore di espressioni matematiche e condizioni logiche
class ExpressionEvaluator {
  /// Valuta un'espressione matematica
  static dynamic evaluateMath(String expression) {
    try {
      // Se è solo un numero, restituiscilo direttamente
      final numValue = num.tryParse(expression);
      if (numValue != null) return numValue;

      // Usa il parser di math_expressions per espressioni complesse
      final parser = GrammarParser();
      Expression exp;

      try {
        exp = parser.parse(expression);
      } catch (e) {
        // Gestione operatori di confronto manualmente
        return _handleComparisonOperators(expression);
      }

      // Valuta l'espressione usando RealEvaluator
      final evaluator = RealEvaluator(ContextModel());
      final result = evaluator.evaluate(exp);

      return result;
    } catch (e) {
      throw Exception('Errore valutazione: ${e.toString()}');
    }
  }

  /// Gestisce operatori di confronto non supportati dal parser matematico
  static dynamic _handleComparisonOperators(String expression) {
    if (expression.contains('>=')) {
      final parts = expression.split('>=');
      if (parts.length == 2) {
        final left = evaluateMath(parts[0].trim());
        final right = evaluateMath(parts[1].trim());
        return (left is num && right is num && left >= right) ? 1 : 0;
      }
    } else if (expression.contains('<=')) {
      final parts = expression.split('<=');
      if (parts.length == 2) {
        final left = evaluateMath(parts[0].trim());
        final right = evaluateMath(parts[1].trim());
        return (left is num && right is num && left <= right) ? 1 : 0;
      }
    } else if (expression.contains('==')) {
      final parts = expression.split('==');
      if (parts.length == 2) {
        final left = evaluateMath(parts[0].trim());
        final right = evaluateMath(parts[1].trim());
        return (left == right) ? 1 : 0;
      }
    } else if (expression.contains('!=')) {
      final parts = expression.split('!=');
      if (parts.length == 2) {
        final left = evaluateMath(parts[0].trim());
        final right = evaluateMath(parts[1].trim());
        return (left != right) ? 1 : 0;
      }
    } else if (expression.contains('>') && !expression.contains('>=')) {
      final parts = expression.split('>');
      if (parts.length == 2) {
        final left = evaluateMath(parts[0].trim());
        final right = evaluateMath(parts[1].trim());
        return (left is num && right is num && left > right) ? 1 : 0;
      }
    } else if (expression.contains('<') && !expression.contains('<=')) {
      final parts = expression.split('<');
      if (parts.length == 2) {
        final left = evaluateMath(parts[0].trim());
        final right = evaluateMath(parts[1].trim());
        return (left is num && right is num && left < right) ? 1 : 0;
      }
    }

    throw Exception('Operatore non supportato');
  }

  /// Valuta una condizione con operatori logici (&&, ||, !)
  static dynamic evaluateCondition(String expression) {
    var expr = expression.trim();

    // Scorciatoie: booleani letterali e numeri
    if (expr.toLowerCase() == 'true') return true;
    if (expr.toLowerCase() == 'false') return false;
    final asNum = num.tryParse(expr);
    if (asNum != null) return asNum;

    // Rimuovi parentesi esterne ridondanti
    expr = _stripOuterParentheses(expr);

    // 1) OR logico a livello top-level
    final orSplit = _splitAtTopLevel(expr, '||');
    if (orSplit != null) {
      final left = evaluateCondition(orSplit[0]);
      final right = evaluateCondition(orSplit[1]);
      final l = (left is bool) ? left : (left != 0);
      final r = (right is bool) ? right : (right != 0);
      return l || r;
    }

    // 2) AND logico a livello top-level
    final andSplit = _splitAtTopLevel(expr, '&&');
    if (andSplit != null) {
      final left = evaluateCondition(andSplit[0]);
      final right = evaluateCondition(andSplit[1]);
      final l = (left is bool) ? left : (left != 0);
      final r = (right is bool) ? right : (right != 0);
      return l && r;
    }

    // 3) NOT logico (unario) all'inizio dell'espressione
    if (expr.startsWith('!')) {
      final inner = evaluateCondition(expr.substring(1).trim());
      final v = (inner is bool) ? inner : (inner != 0);
      return !v;
    }

    // 4) Confronti (tenere ordinamento: doppi operatori prima dei singoli)
    for (final op in const ['>=', '<=', '==', '!=']) {
      final parts = _splitAtTopLevel(expr, op);
      if (parts != null) {
        final left = evaluateCondition(parts[0]);
        final right = evaluateCondition(parts[1]);
        switch (op) {
          case '>=':
            return (left is num && right is num && left >= right) ? 1 : 0;
          case '<=':
            return (left is num && right is num && left <= right) ? 1 : 0;
          case '==':
            return (left == right) ? 1 : 0;
          case '!=':
            return (left != right) ? 1 : 0;
        }
      }
    }

    // 5) Confronti singoli
    for (final op in const ['>', '<']) {
      final parts = _splitAtTopLevel(expr, op);
      if (parts != null) {
        final left = evaluateCondition(parts[0]);
        final right = evaluateCondition(parts[1]);
        switch (op) {
          case '>':
            return (left is num && right is num && left > right) ? 1 : 0;
          case '<':
            return (left is num && right is num && left < right) ? 1 : 0;
        }
      }
    }

    // 6) Nessun operatore logico/di confronto: valuta come espressione matematica
    return evaluateMath(expr);
  }

  /// Sanifica/normalizza la condizione prima della valutazione
  static String sanitizeCondition(String expression) {
    var s = expression.trim();

    // rimuovi eventuale ';' finale o spazi in eccesso
    if (s.endsWith(';')) {
      s = s.substring(0, s.length - 1).trim();
    }

    // normalizza operatori testuali in logici
    s = s.replaceAll(RegExp(r'\bAND\b', caseSensitive: false), '&&');
    s = s.replaceAll(RegExp(r'\bOR\b', caseSensitive: false), '||');
    s = s.replaceAll(RegExp(r'\bNOT\b', caseSensitive: false), '!');

    // conversione '=' singolo in '==' preservando >=, <=, !=, ==
    s = s
        .replaceAll('>=', '__GE__')
        .replaceAll('<=', '__LE__')
        .replaceAll('!=', '__NE__')
        .replaceAll('==', '__EQ__');
    s = s.replaceAll('=', '==');
    s = s
        .replaceAll('__GE__', '>=')
        .replaceAll('__LE__', '<=')
        .replaceAll('__NE__', '!=')
        .replaceAll('__EQ__', '==');

    // compatta spazi multipli
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  /// Rimuove una coppia di parentesi esterne se racchiudono interamente l'espressione
  static String _stripOuterParentheses(String s) {
    while (s.length >= 2 && s.startsWith('(') && s.endsWith(')')) {
      var depth = 0;
      var enclosesAll = true;
      for (int i = 0; i < s.length; i++) {
        final c = s[i];
        if (c == '(') depth++;
        if (c == ')') {
          depth--;
          if (depth == 0 && i != s.length - 1) {
            enclosesAll = false;
            break;
          }
        }
      }
      if (enclosesAll) {
        s = s.substring(1, s.length - 1).trim();
      } else {
        break;
      }
    }
    return s;
  }

  /// Divide l'espressione al primo operatore trovato a livello top-level
  static List<String>? _splitAtTopLevel(String s, String operator) {
    int depth = 0;
    for (int i = 0; i <= s.length - operator.length; i++) {
      final c = s[i];
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth < 0) depth = 0;
      }

      if (depth == 0 && s.substring(i, i + operator.length) == operator) {
        final left = s.substring(0, i).trim();
        final right = s.substring(i + operator.length).trim();
        return [left, right];
      }
    }
    return null;
  }
}

