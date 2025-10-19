// filepath: lib/config/services/execution_engine.dart
import 'package:flowchart_repository/flowchart_repository.dart';
import 'expression_parser.dart';
import 'models/execution_result.dart';

/// Risultato della valutazione di una decisione
class DecisionResult {
  final bool result;
  final bool success;
  final String? errorMessage;

  const DecisionResult({
    required this.result,
    this.success = true,
    this.errorMessage,
  });

  DecisionResult.success(bool value)
      : result = value,
        success = true,
        errorMessage = null;

  DecisionResult.error(String message)
      : result = false,
        success = false,
        errorMessage = message;
}

// ============================================================================
// 🎯 EXECUTION ENGINE - LOGICA PURA (Stateless, Testabile)
// ============================================================================
//
// REGOLA CRITICA: L'esecuzione avviene IMMEDIATAMENTE quando si entra nel nodo
// NON quando si esce. Questo vale per TUTTI i tipi di nodo.
//
// Se un nodo richiede input (AssignmentNode con espressioni vuote),
// lo stato diventa DebugAwaitingInput e il BLoC gestisce l'input utente.
//
// ============================================================================

class ExecutionEngine {
  // ==========================================================================
  // 🚀 ESECUZIONE NODO (Entry Point)
  // ==========================================================================

  static Future<ExecutionResult> executeNode({
    required FlowNode node,
    required Map<String, dynamic> variables,
    required List<VariableDeclaration> allVariables,
  }) async {
    try {
      return switch (node.kind) {
        FlowNodeKind.start => _start(),
        FlowNodeKind.end => _end(),
        FlowNodeKind.input => _input(node as InputNode, variables, allVariables),
        FlowNodeKind.assignment => _assignment(node as AssignmentNode, variables, allVariables),
        FlowNodeKind.output => _output(node as OutputNode, variables, allVariables),
        FlowNodeKind.process => _process(node as ProcessNode, variables),
        FlowNodeKind.returnNode => _return(node as ReturnNode, variables),
        FlowNodeKind.functionHeader => ExecutionResult.success(
          message: 'Funzione: ${(node as FunctionHeaderNode).signatureText}',
        ),
        FlowNodeKind.decision => _decision(node as DecisionNode, variables, allVariables),
        FlowNodeKind.whileLoop => _whileLoop(node as WhileNode, variables, allVariables),
        FlowNodeKind.doWhileLoop => _doWhileLoop(node as DoWhileNode, variables, allVariables),
        FlowNodeKind.doWhileStart => ExecutionResult.success(message: 'Do-While start'),
      };
    } catch (e) {
      return ExecutionResult.error('Errore: ${e.toString()}');
    }
  }

  // ==========================================================================
  // 📝 LOGICA NODI
  // ==========================================================================

  static ExecutionResult _start() {
    return ExecutionResult.success(message: '▶️ Avvio');
  }

  static ExecutionResult _end() {
    // NON chiudere la sessione qui: l'utente è appena ARRIVATO al nodo End.
    // La fine del percorso verrà segnalata SOLO se l'utente preme Next ancora (oltre l'ultimo nodo).
    return ExecutionResult.success(message: '⏹️ Fine');
  }

  /// INPUT NODE: Dichiara variabili con null
  ///
  /// ESECUZIONE IMMEDIATA: Non appena si entra nel nodo Input,
  /// tutte le variabili di input vengono dichiarate nello scope (con valore null).
  static ExecutionResult _input(InputNode node, Map<String, dynamic> vars, List<VariableDeclaration> allVars) {
    final updates = <String, dynamic>{};
    final declared = allVars.map((v) => v.name).toSet();

    for (final varName in node.targetVariables) {
      if (!declared.contains(varName)) {
        return ExecutionResult.error('Variabile di input "$varName" non dichiarata nel flowchart');
      }
      if (!vars.containsKey(varName)) {
        updates[varName] = null;
      }
    }

    return ExecutionResult.success(
      updatedVariables: updates,
      message: updates.isEmpty
          ? '✓ INPUT già esistenti'
          : '📥 INPUT dichiarate: ${updates.keys.join(', ')}',
    );
  }

  /// ASSIGNMENT NODE: Assegna valori alle variabili
  ///
  /// ESECUZIONE IMMEDIATA: Non appena si entra nel nodo Assignment,
  /// se tutte le espressioni sono definite, vengono SUBITO valutate e assegnate.
  /// Se ci sono espressioni vuote (runtime assignment), rimane in DebugAwaitingInput.
  ///
  /// TYPE CHECKING: Ogni assegnazione valida il tipo target
  static ExecutionResult _assignment(
    AssignmentNode node,
    Map<String, dynamic> vars,
    List<VariableDeclaration> allVars,
  ) {
    print('🔴 INIZIO _assignment');
    final updates = <String, dynamic>{};
    final messages = <String>[];
    final pendingRuntimeTargets = <String>[]; // target ancora da valorizzare

    // Helper per trovare dichiarazione
    VariableDeclaration? _findDecl(String name) {
      try {
        return allVars.firstWhere((v) => v.name == name);
      } catch (_) {
        return null;
      }
    }

    for (final assignment in node.assignments) {
      final target = assignment.target.trim();
      if (target.isEmpty) {
        return ExecutionResult.error('Target di assegnazione vuoto');
      }

      final decl = _findDecl(target);
      if (decl == null) {
        return ExecutionResult.error('Variabile "$target" non dichiarata nel flowchart');
      }

      // Se è INPUT scope, deve essere già stata dichiarata in Input precedente
      if (decl.scope == VariableScope.input && !vars.containsKey(target)) {
        return ExecutionResult.error(
          'Variabile di input "$target" non dichiarata da blocco Input precedente',
        );
      }

      final expr = (assignment.expression).trim();

      // Se espressione è vuota: runtime assignment
      if (expr.isEmpty) {
        // Se il valore è già presente (non-null), consideralo completato; altrimenti segna come pending
        final hasValue = vars.containsKey(target) && vars[target] != null;
        if (!hasValue) {
          pendingRuntimeTargets.add(target);
          // Assicurati che la variabile esista nella sessione per essere mostrata con valore null
          if (!vars.containsKey(target)) {
            updates[target] = null;
          }
          print('🟡 Runtime assignment per: $target (no expr)');
        } else {
          // Già valorizzata dall'utente in un passo precedente: nessuna azione
          print('🟢 Runtime assignment già valorizzato: $target = ${vars[target]}');
        }
        continue;
      }

      // Espressione definita: valuta e assegna IMMEDIATAMENTE con type checking
      print('🟢 Valutando: $target = $expr');
      final result = ExpressionParser.evaluate(
        expr,
        vars,
        targetDeclaration: decl,
      );

      if (!result.isValid) {
        final msg = result.errorMessage ?? 'espressione non valida';
        final isTypeMismatch = msg.contains('Tipo incompatibile') || msg.contains('Conversione non permessa');
        return ExecutionResult.error(
          'Errore: $target = ${assignment.expression}\n$msg',
          blocking: !isTypeMismatch,
        );
      }

      updates[target] = result.value;
      print('✅ ASSEGNATO: $target = ${result.value}');
      messages.add('$target = ${result.value}');
    }

    // Se ci sono target con runtime assignment non ancora valorizzati: chiedi input all'utente
    if (pendingRuntimeTargets.isNotEmpty) {
      print('⏸️ RICHIEDO INPUT per: $pendingRuntimeTargets');
      return ExecutionResult(
        success: true,
        updatedVariables: updates, // include eventuali inizializzazioni a null o assegnazioni pronte
        requiresUserInput: true,
        userInputPrompt: 'Assegna: ${pendingRuntimeTargets.join(', ')}',
      );
    }

    print('🎉 _assignment COMPLETATO: $updates');
    return ExecutionResult.success(
      updatedVariables: updates,
      message: messages.isEmpty ? '✏️ Assegnazioni pronte' : '✏️ ${messages.join(', ')}',
    );
  }

  /// OUTPUT NODE: Mostra messaggio con validazione variabili dichiarate e template {{var}}
  static ExecutionResult _output(OutputNode node, Map<String, dynamic> vars, List<VariableDeclaration> allVars) {
    final declaredByName = {for (final v in allVars) v.name: v};

    final template = node.template;
    final regex = RegExp(r'\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}');
    final matches = regex.allMatches(template);

    // Se il template contiene segnaposti, usiamo quelli; altrimenti ricadiamo su node.variables
    final referencedNames = <String>{};
    for (final m in matches) {
      final name = m.group(1);
      if (name != null && name.isNotEmpty) referencedNames.add(name);
    }
    if (referencedNames.isEmpty) {
      referencedNames.addAll(node.variables.map((v) => v.name));
    }

    // Validazioni richieste (tutte bloccanti):
    // 1) variabile esiste nel flowchart
    // 2) variabile è di scope output
    // 3) variabile ha valore non nullo nella sessione
    for (final name in referencedNames) {
      final decl = declaredByName[name];
      if (decl == null) {
        return ExecutionResult.error('❌ Errore: Variabile "$name" non dichiarata nel flowchart');
      }
      if (decl.scope != VariableScope.output) {
        return ExecutionResult.error('❌ Errore: "$name" non è una variabile di tipo output');
      }
      if (!vars.containsKey(name)) {
        return ExecutionResult.error('❌ Errore: Variabile "$name" non disponibile nella sessione');
      }
      if (vars[name] == null) {
        return ExecutionResult.error('❌ Errore: Variabile di output "$name" è null al momento della stampa');
      }
    }

    // Costruzione messaggio
    String message;
    if (template.isNotEmpty) {
      message = template.replaceAllMapped(regex, (m) {
        final vname = m.group(1)!;
        final value = vars[vname];
        return value?.toString() ?? 'null';
      });
    } else if (referencedNames.isNotEmpty) {
      message = referencedNames.map((n) => '$n=${vars[n]}').join(', ');
    } else {
      message = '';
    }

    return ExecutionResult.success(
      message: message.isEmpty ? '📤' : '📤 $message',
    );
  }

  /// PROCESS NODE: Chiamata sottoprogramma
  static ExecutionResult _process(ProcessNode node, Map<String, dynamic> vars) {
    final args = <dynamic>[];

    for (final argExpr in node.arguments) {
      final result = ExpressionParser.evaluate(argExpr, vars);
      if (!result.isValid) {
        final msg = result.errorMessage ?? 'argomento non valido';
        final isTypeMismatch = msg.contains('Tipo incompatibile') || msg.contains('Conversione non permessa');
        return ExecutionResult.error('Errore arg "$argExpr": $msg', blocking: !isTypeMismatch);
      }
      args.add(result.value);
    }

    return ExecutionResult.subprogramCall(node.flowchartToCall);
  }

  /// RETURN NODE: Ritorna valore
  static ExecutionResult _return(ReturnNode node, Map<String, dynamic> vars) {
    if (node.returnExpression == null || node.returnExpression!.isEmpty) {
      return ExecutionResult.withReturn(null);
    }

    final result = ExpressionParser.evaluate(node.returnExpression!, vars);
    if (!result.isValid) {
      final msg = result.errorMessage ?? 'espressione non valida';
      final isTypeMismatch = msg.contains('Tipo incompatibile') || msg.contains('Conversione non permessa');
      return ExecutionResult.error('Errore return: $msg', blocking: !isTypeMismatch);
    }

    return ExecutionResult.withReturn(result.value);
  }

  // ==========================================================================
  // 🎲 DECISIONI E CICLI
  // ==========================================================================

  /// DECISION NODE: Valuta condizione e comunica il branch (con validazione dichiarazioni)
  static ExecutionResult _decision(DecisionNode node, Map<String, dynamic> vars, List<VariableDeclaration> allVars) {
    final declared = allVars.map((v) => v.name).toSet();

    for (final c in node.clauses) {
      if (!declared.contains(c.leftOperand)) {
        return ExecutionResult.error('Variabile "${c.leftOperand}" non dichiarata nel flowchart', blocking: false);
      }
      if (!vars.containsKey(c.leftOperand)) {
        return ExecutionResult.error('Variabile "${c.leftOperand}" non disponibile nella sessione', blocking: false);
      }
      if (!c.isRightLiteral) {
        if (!declared.contains(c.rightOperand)) {
          return ExecutionResult.error('Variabile "${c.rightOperand}" non dichiarata nel flowchart', blocking: false);
        }
        if (!vars.containsKey(c.rightOperand)) {
          return ExecutionResult.error('Variabile "${c.rightOperand}" non disponibile nella sessione', blocking: false);
        }
      }
    }

    // Valutazione con type-check rigoroso; in caso di mismatch lancia eccezione che verrà catturata come errore bloccante
    final result = evaluateCondition(
      clauses: node.clauses,
      logicalJoin: node.logicalJoin,
      variables: vars,
    );

    final branch = result ? 'true' : 'false';
    final condition = node.clauses
        .map((c) => '${c.leftOperand} ${c.operator} ${c.rightOperand}')
        .join(' ${node.logicalJoin} ');

    return ExecutionResult.success(
      message: '🔀 Decisione: $condition → ${result ? "VERO" : "FALSO"}',
      decisionBranch: branch,
    );
  }

  /// WHILE NODE: Valuta condizione loop con validazione
  static ExecutionResult _whileLoop(WhileNode node, Map<String, dynamic> vars, List<VariableDeclaration> allVars) {
    final declared = allVars.map((v) => v.name).toSet();
    for (final c in node.clauses) {
      if (!declared.contains(c.leftOperand)) {
        return ExecutionResult.error('Variabile "${c.leftOperand}" non dichiarata nel flowchart', blocking: false);
      }
      if (!vars.containsKey(c.leftOperand)) {
        return ExecutionResult.error('Variabile "${c.leftOperand}" non disponibile nella sessione', blocking: false);
      }
      if (!c.isRightLiteral) {
        if (!declared.contains(c.rightOperand)) {
          return ExecutionResult.error('Variabile "${c.rightOperand}" non dichiarata nel flowchart', blocking: false);
        }
        if (!vars.containsKey(c.rightOperand)) {
          return ExecutionResult.error('Variabile "${c.rightOperand}" non disponibile nella sessione', blocking: false);
        }
      }
    }

    final result = evaluateCondition(
      clauses: node.clauses,
      logicalJoin: node.logicalJoin,
      variables: vars,
    );

    final branch = result ? 'true' : 'false';
    final condition = node.clauses
        .map((c) => '${c.leftOperand} ${c.operator} ${c.rightOperand}')
        .join(' ${node.logicalJoin} ');

    return ExecutionResult.success(
      message: '🔁 While: $condition → ${result ? "ENTRA nel ciclo" : "SALTA il ciclo"}',
      decisionBranch: branch,
    );
  }

  /// DO-WHILE NODE: Valuta condizione dopo il corpo con validazione
  static ExecutionResult _doWhileLoop(DoWhileNode node, Map<String, dynamic> vars, List<VariableDeclaration> allVars) {
    final declared = allVars.map((v) => v.name).toSet();
    for (final c in node.clauses) {
      if (!declared.contains(c.leftOperand)) {
        return ExecutionResult.error('Variabile "${c.leftOperand}" non dichiarata nel flowchart', blocking: false);
      }
      if (!vars.containsKey(c.leftOperand)) {
        return ExecutionResult.error('Variabile "${c.leftOperand}" non disponibile nella sessione', blocking: false);
      }
      if (!c.isRightLiteral) {
        if (!declared.contains(c.rightOperand)) {
          return ExecutionResult.error('Variabile "${c.rightOperand}" non dichiarata nel flowchart', blocking: false);
        }
        if (!vars.containsKey(c.rightOperand)) {
          return ExecutionResult.error('Variabile "${c.rightOperand}" non disponibile nella sessione', blocking: false);
        }
      }
    }

    final result = evaluateCondition(
      clauses: node.clauses,
      logicalJoin: node.logicalJoin,
      variables: vars,
    );

    final branch = result ? 'true' : 'false';
    final condition = node.clauses
        .map((c) => '${c.leftOperand} ${c.operator} ${c.rightOperand}')
        .join(' ${node.logicalJoin} ');

    return ExecutionResult.success(
      message: '🔁 Do-While: $condition → ${result ? "RIPETI (loop)" : "ESCI"}',
      decisionBranch: result ? 'loop' : 'false',
    );
  }

  // ==========================================================================
  // 🎲 VALUTAZIONE CONDIZIONI (Usata da Decision, While, DoWhile)
  // ==========================================================================

  static bool evaluateCondition({
    required List<ConditionClause> clauses,
    required String logicalJoin,
    required Map<String, dynamic> variables,
  }) {
    if (clauses.isEmpty) return true;

    bool _isNumericOp(String op) => op == '<' || op == '<=' || op == '>' || op == '>=';
    bool _isEqualityOp(String op) => op == '==' || op == '!=';
    bool _isContainsOp(String op) => op == 'contains' || op == '!contains';

    num? _toNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      if (v is String) return num.tryParse(v.trim());
      return null;
    }

    bool? _toBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true') return true;
        if (s == 'false') return false;
      }
      return null;
    }

    bool evalClause(ConditionClause clause) {
      final leftRaw = variables[clause.leftOperand];
      final rightRaw = clause.isRightLiteral
          ? _parseLiteral(clause.rightOperand)
          : variables[clause.rightOperand];

      final op = clause.operator;

      if (_isNumericOp(op)) {
        final ln = _toNum(leftRaw);
        final rn = _toNum(rightRaw);
        if (ln == null || rn == null) {
          throw FormatException('Type mismatch: operatore "$op" richiede numeri (left=${leftRaw.runtimeType}, right=${rightRaw.runtimeType})');
        }
        return _compare(ln, rn, op);
      }

      if (_isContainsOp(op)) {
        final ls = leftRaw?.toString() ?? '';
        final rs = rightRaw?.toString() ?? '';
        return _compare(ls, rs, op);
      }

      if (_isEqualityOp(op)) {
        // Tenta confronto numerico se entrambi numerici o convertibili
        final ln = _toNum(leftRaw);
        final rn = _toNum(rightRaw);
        if (ln != null && rn != null) {
          return _compare(ln, rn, op);
        }
        // Tenta confronto booleano se applicabile
        final lb = _toBool(leftRaw);
        final rb = _toBool(rightRaw);
        if (lb != null && rb != null) {
          return _compare(lb, rb, op);
        }
        // Gestisci null esplicitamente
        if (leftRaw == null || rightRaw == null) {
          return op == '==' ? leftRaw == rightRaw : leftRaw != rightRaw;
        }
        // Fallback: confronto diretto dei valori
        return _compare(leftRaw, rightRaw, op);
      }

      // Operatore non supportato: considera falso
      return false;
    }

    final results = clauses.map(evalClause).toList();

    return logicalJoin.toUpperCase() == 'AND'
        ? results.every((r) => r)
        : results.any((r) => r);
  }

  static bool _compare(dynamic left, dynamic right, String operator) {
    return switch (operator) {
      '==' => left == right,
      '!=' => left != right,
      '<' => (left as num) < (right as num),
      '<=' => (left as num) <= (right as num),
      '>' => (left as num) > (right as num),
      '>=' => (left as num) >= (right as num),
      'contains' => left.toString().contains(right.toString()),
      '!contains' => !left.toString().contains(right.toString()),
      _ => false,
    };
  }

  static dynamic _parseLiteral(String literal) {
    if (literal.startsWith('"') || literal.startsWith('\'')) {
      return literal.substring(1, literal.length - 1);
    }
    final numValue = num.tryParse(literal);
    if (numValue != null) return numValue;

    if (literal.toLowerCase() == 'true') return true;
    if (literal.toLowerCase() == 'false') return false;

    return literal;
  }
}
