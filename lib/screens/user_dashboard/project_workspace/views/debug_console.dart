import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:math_expressions/math_expressions.dart';

/// 🖥️ Console Interattiva stile Terminale per il Debug Mode
class DebugConsole extends StatefulWidget {
  final FlowNode currentNode;
  final String flowchartId;
  final dynamic projectRepo;
  final List<VariableDeclaration> allVariables;
  final VoidCallback onCommandExecuted;

  const DebugConsole({
    super.key,
    required this.currentNode,
    required this.flowchartId,
    required this.projectRepo,
    required this.allVariables,
    required this.onCommandExecuted,
  });

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final List<ConsoleEntry> _history = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isWaitingForInput = false;
  String? _currentPrompt;
  String? _currentVariable;
  Map<String, dynamic> _pendingValues = {};
  List<String> _variablesQueue = [];

  @override
  void initState() {
    super.initState();
    _initializeForNode();

    // Auto-focus sull'input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant DebugConsole oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Se il nodo è cambiato, reinizializza
    if (widget.currentNode.id != oldWidget.currentNode.id) {
      _initializeForNode();
    }
  }

  void _initializeForNode() {
    _history.clear();
    _pendingValues.clear();
    _variablesQueue.clear();
    _isWaitingForInput = false;

    setState(() {
      _addSystemMessage('=== ${widget.currentNode.text.toUpperCase()} ===');
      _addSystemMessage('Tipo: ${widget.currentNode.kind.name.toUpperCase()}');
      _addSystemMessage('');

      if (widget.currentNode is AssignmentNode) {
        final node = widget.currentNode as AssignmentNode;
        _addInfoMessage('Sintassi: {variabile} per usare valori esistenti');
        _addInfoMessage('Esempio: {prezzo} * 1.22');
        _addSystemMessage('');

        _variablesQueue = node.assignments.map((a) => a.target).toList();
        _promptNextVariable();
      } else if (widget.currentNode is OutputNode) {
        final node = widget.currentNode as OutputNode;
        _addInfoMessage('Template: ${node.template}');
        _addInfoMessage('Sintassi: {variabile} per usare valori esistenti');
        _addSystemMessage('');

        _variablesQueue = node.variables.map((v) => v.name).toList();
        _promptNextVariable();
      } else if (widget.currentNode is DecisionNode) {
        // 🆕 DECISION NODE - comportamento come OUTPUT
        final node = widget.currentNode as DecisionNode;
        _addInfoMessage('Condizione: ${node.condition}');
        _addInfoMessage('Sintassi: {variabile} per usare valori esistenti');
        _addSystemMessage('');

        // Estrai le variabili di lavoro dalla condizione
        final varsInCondition = _extractVariablesFromCondition(node.condition);
        _variablesQueue = varsInCondition;

        if (_variablesQueue.isNotEmpty) {
          _promptNextVariable();
        } else {
          _addInfoMessage('Nessuna variabile da assegnare');
          _addInfoMessage('Usa il pulsante "Avanti" per continuare');
        }
      } else {
        // Per nodi senza input (start, end, process, ecc.)
        _addInfoMessage('Questo nodo non richiede input');
        _addInfoMessage('Usa il pulsante "Avanti" per continuare');
        _addSystemMessage('');
      }
    });
  }

  void _promptNextVariable() {
    if (_variablesQueue.isEmpty) {
      // Tutte le variabili sono state inserite
      _isWaitingForInput = false;

      // Per ASSIGNMENT, tutte le variabili sono già salvate individualmente
      if (widget.currentNode is AssignmentNode) {
        _addSystemMessage('');
        _addSuccessMessage('✓ Tutte le assegnazioni completate');
        _addInfoMessage('Usa il pulsante "Avanti" per continuare');
        widget.onCommandExecuted();
      }
      // 🆕 Per DECISION, valuta la condizione dopo aver salvato tutte le variabili
      else if (widget.currentNode is DecisionNode) {
        _addSystemMessage('');
        _addSuccessMessage('✓ Tutte le variabili assegnate');

        // 🆕 VALUTA LA CONDIZIONE per determinare il ramo da prendere
        final decisionNode = widget.currentNode as DecisionNode;
        _evaluateDecisionCondition(decisionNode.condition);

        _addInfoMessage('Usa il pulsante "Avanti" per continuare');
        widget.onCommandExecuted();
      }
      // Per OUTPUT, il rendering è già stato fatto nell'ultimo _handleInput

      setState(() {});
      return;
    }

    final varName = _variablesQueue.removeAt(0);
    _currentVariable = varName;

    final varDecl = widget.allVariables.firstWhere(
      (v) => v.name == varName,
      orElse: () => VariableDeclaration(name: varName, dataType: 'string'),
    );

    _currentPrompt = '$varName (${varDecl.dataType})';
    _isWaitingForInput = true;

    setState(() {
      _addPrompt(_currentPrompt!);
    });

    _scrollToBottom();
  }

  /// Estrae le variabili di lavoro da una condizione
  List<String> _extractVariablesFromCondition(String condition) {
    final List<String> foundVariables = [];

    for (final variable in widget.allVariables) {
      // Cerca solo variabili di lavoro (scope local)
      if (variable.scope == VariableScope.local) {
        // Cerca il nome della variabile come parola intera nella condizione
        final pattern = RegExp(r'\b' + RegExp.escape(variable.name) + r'\b');
        if (pattern.hasMatch(condition)) {
          foundVariables.add(variable.name);
        }
      }
    }

    return foundVariables;
  }

  Future<void> _finalizeExecution() async {
    _isWaitingForInput = false;

    if (_pendingValues.isEmpty) {
      _addErrorMessage('Nessun valore da salvare');
      return;
    }

    try {
      // Salva i valori in sessione
      await widget.projectRepo.updateDebugVariables(
        projectId: widget.flowchartId,
        variables: _pendingValues,
      );

      // Se è un output, renderizza il template
      if (widget.currentNode is OutputNode) {
        final outputNode = widget.currentNode as OutputNode;
        final allVars = await widget.projectRepo.getDebugVariables(
          projectId: widget.flowchartId,
        );

        final rendered = _renderTemplate(outputNode.template, allVars);
        _addOutputMessage(rendered);
      }

      _addSuccessMessage('✓ Operazione completata');
      _addSystemMessage('');
      _addInfoMessage('Usa il pulsante "Avanti" per continuare');

      widget.onCommandExecuted();
    } catch (e) {
      _addErrorMessage('Errore: ${e.toString()}');
    }

    setState(() {});
    _scrollToBottom();
  }

  Future<void> _handleInput(String input) async {
    if (!_isWaitingForInput || _currentVariable == null) return;

    final trimmedInput = input.trim();

    // Aggiungi l'input alla history
    _addUserInput(trimmedInput);
    _inputController.clear();

    if (trimmedInput.isEmpty) {
      _addErrorMessage('Input vuoto non valido');
      _addPrompt(_currentPrompt!);
      setState(() {});
      return;
    }

    // Risolvi il valore
    try {
      final resolved = await _resolveValue(trimmedInput, _currentVariable!);

      if (resolved.error != null) {
        _addErrorMessage(resolved.error!);
        _addPrompt(_currentPrompt!);
        setState(() {});
        return;
      }

      // Converti nel tipo corretto
      final varDecl = widget.allVariables.firstWhere(
        (v) => v.name == _currentVariable!,
        orElse: () => VariableDeclaration(name: _currentVariable!, dataType: 'string'),
      );

      final convertedValue = _convertResolvedValue(resolved.value, varDecl.dataType);

      // 🆕 SALVATAGGIO IMMEDIATO - Salva la variabile subito, non alla fine
      await widget.projectRepo.updateDebugVariables(
        projectId: widget.flowchartId,
        variables: {_currentVariable!: convertedValue},
      );

      _addSuccessMessage('✓ ${_currentVariable!} = $convertedValue (salvato)');

      // Se è l'ultima variabile di un OUTPUT, renderizza il template
      if (widget.currentNode is OutputNode && _variablesQueue.isEmpty) {
        final outputNode = widget.currentNode as OutputNode;
        final allVars = await widget.projectRepo.getDebugVariables(
          projectId: widget.flowchartId,
        );

        final rendered = _renderTemplate(outputNode.template, allVars);
        _addOutputMessage(rendered);
        _addSystemMessage('');
        _addInfoMessage('Usa il pulsante "Avanti" per continuare');

        widget.onCommandExecuted();
      }

      // Passa alla prossima variabile
      _promptNextVariable();
    } catch (e) {
      _addErrorMessage('Errore: ${e.toString()}');
      _addPrompt(_currentPrompt!);
    }

    setState(() {});
    _scrollToBottom();
  }

  Future<ResolvedValue> _resolveValue(String input, String targetVarName) async {
    final trimmedInput = input.trim();

    if (trimmedInput.isEmpty) {
      return ResolvedValue.error('Input vuoto');
    }

    final sessionVars = await widget.projectRepo.getDebugVariables(
      projectId: widget.flowchartId,
    );

    // Verifica se contiene riferimenti a variabili {nome}
    final varPattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    final hasVariables = varPattern.hasMatch(trimmedInput);

    if (hasVariables) {
      final varMatches = varPattern.allMatches(trimmedInput);
      final referencedVars = <String>[];

      for (final match in varMatches) {
        final varName = match.group(1)!;
        referencedVars.add(varName);

        if (!sessionVars.containsKey(varName)) {
          return ResolvedValue.error(
            'Variabile "$varName" non trovata'
          );
        }

        final value = sessionVars[varName];
        if (value == null || (value is String && value.isEmpty)) {
          return ResolvedValue.error(
            'Variabile "$varName" non ha valore'
          );
        }
      }

      if (trimmedInput == '{${referencedVars.first}}' && referencedVars.length == 1) {
        return ResolvedValue.success(sessionVars[referencedVars.first]!, isLiteral: false);
      }

      String processedExpression = trimmedInput;

      for (final varName in referencedVars) {
        final value = sessionVars[varName];
        processedExpression = processedExpression.replaceAll(
          '{$varName}',
          value.toString(),
        );
      }

      final hasOperators = RegExp(r'[+\-*/()%]').hasMatch(processedExpression);

      if (hasOperators) {
        try {
          // Valuta espressione matematica
          final result = _evaluateMathExpression(processedExpression);
          return ResolvedValue.success(result, isLiteral: false);
        } catch (e) {
          return ResolvedValue.error('Errore valutazione: ${e.toString()}');
        }
      } else {
        return ResolvedValue.success(processedExpression, isLiteral: false);
      }
    }

    // Letterali
    final intValue = int.tryParse(trimmedInput);
    if (intValue != null) {
      return ResolvedValue.success(intValue, isLiteral: true);
    }

    final doubleValue = double.tryParse(trimmedInput);
    if (doubleValue != null) {
      return ResolvedValue.success(doubleValue, isLiteral: true);
    }

    if (trimmedInput.toLowerCase() == 'true') {
      return ResolvedValue.success(true, isLiteral: true);
    }
    if (trimmedInput.toLowerCase() == 'false') {
      return ResolvedValue.success(false, isLiteral: true);
    }

    return ResolvedValue.success(trimmedInput, isLiteral: true);
  }

  dynamic _evaluateMathExpression(String expression) {
    try {
      // Se è solo un numero, restituiscilo direttamente
      final numValue = num.tryParse(expression);
      if (numValue != null) {
        return numValue;
      }

      // Usa il parser di math_expressions per espressioni complesse
      final parser = GrammarParser();
      Expression exp;

      try {
        exp = parser.parse(expression);
      } catch (e) {
        // Se il parser fallisce, prova con operatori di confronto
        // Gestione operatori di confronto manualmente
        if (expression.contains('>=')) {
          final parts = expression.split('>=');
          if (parts.length == 2) {
            final left = _evaluateMathExpression(parts[0].trim());
            final right = _evaluateMathExpression(parts[1].trim());
            return (left is num && right is num && left >= right) ? 1 : 0;
          }
        } else if (expression.contains('<=')) {
          final parts = expression.split('<=');
          if (parts.length == 2) {
            final left = _evaluateMathExpression(parts[0].trim());
            final right = _evaluateMathExpression(parts[1].trim());
            return (left is num && right is num && left <= right) ? 1 : 0;
          }
        } else if (expression.contains('==')) {
          final parts = expression.split('==');
          if (parts.length == 2) {
            final left = _evaluateMathExpression(parts[0].trim());
            final right = _evaluateMathExpression(parts[1].trim());
            return (left == right) ? 1 : 0;
          }
        } else if (expression.contains('!=')) {
          final parts = expression.split('!=');
          if (parts.length == 2) {
            final left = _evaluateMathExpression(parts[0].trim());
            final right = _evaluateMathExpression(parts[1].trim());
            return (left != right) ? 1 : 0;
          }
        } else if (expression.contains('>') && !expression.contains('>=')) {
          final parts = expression.split('>');
          if (parts.length == 2) {
            final left = _evaluateMathExpression(parts[0].trim());
            final right = _evaluateMathExpression(parts[1].trim());
            return (left is num && right is num && left > right) ? 1 : 0;
          }
        } else if (expression.contains('<') && !expression.contains('<=')) {
          final parts = expression.split('<');
          if (parts.length == 2) {
            final left = _evaluateMathExpression(parts[0].trim());
            final right = _evaluateMathExpression(parts[1].trim());
            return (left is num && right is num && left < right) ? 1 : 0;
          }
        }

        rethrow;
      }

      // Valuta l'espressione usando RealEvaluator
      // RealEvaluator richiede un ContextModel opzionale
      final evaluator = RealEvaluator(ContextModel());
      final result = evaluator.evaluate(exp);

      return result;
    } catch (e) {
      throw Exception('Errore valutazione: ${e.toString()}');
    }
  }

  dynamic _convertResolvedValue(dynamic resolvedValue, String dataType) {
    switch (dataType.toLowerCase()) {
      case 'int':
      case 'integer':
        if (resolvedValue is int) return resolvedValue;
        if (resolvedValue is double) return resolvedValue.toInt();
        if (resolvedValue is String) {
          final parsed = int.tryParse(resolvedValue);
          if (parsed != null) return parsed;
        }
        throw Exception('Impossibile convertire in integer');

      case 'double':
      case 'float':
      case 'number':
        if (resolvedValue is double) return resolvedValue;
        if (resolvedValue is int) return resolvedValue.toDouble();
        if (resolvedValue is String) {
          final parsed = double.tryParse(resolvedValue);
          if (parsed != null) return parsed;
        }
        throw Exception('Impossibile convertire in number');

      case 'bool':
      case 'boolean':
        if (resolvedValue is bool) return resolvedValue;
        if (resolvedValue is String) {
          if (resolvedValue.toLowerCase() == 'true') return true;
          if (resolvedValue.toLowerCase() == 'false') return false;
        }
        throw Exception('Impossibile convertire in boolean');

      case 'string':
      default:
        return resolvedValue.toString();
    }
  }

  /// 🆕 Valuta la condizione di un nodo DECISION
  Future<void> _evaluateDecisionCondition(String condition) async {
    try {
      // Ottieni le variabili correnti
      final sessionVars = await widget.projectRepo.getDebugVariables(
        projectId: widget.flowchartId,
      );

      // Sostituisci le variabili nella condizione
      String evaluableCondition = condition;
      for (final entry in sessionVars.entries) {
        final key = entry.key;
        final value = entry.value;
        final valueStr = (value is bool)
            ? (value ? 'true' : 'false')
            : value.toString();

        // 1) sostituisci forma con graffe {var}
        evaluableCondition = evaluableCondition.replaceAll('{$key}', valueStr);
        // 2) sostituisci occorrenze come parola intera
        evaluableCondition = evaluableCondition.replaceAllMapped(
          RegExp(r'\b' + RegExp.escape(key) + r'\b'),
          (match) => valueStr,
        );
      }

      // Normalizza/sanifica la condizione (rimuove ';', converte AND/OR/NOT)
      evaluableCondition = _sanitizeCondition(evaluableCondition);

      // Valuta la condizione (gestisce operatori logici e di confronto)
      final result = _evaluateConditionExpression(evaluableCondition);
      final boolResult = (result is bool) ? result : (result != 0);

      // Mostra il risultato
      _addSystemMessage('');
      _addInfoMessage('Valutazione: $condition');
      _addInfoMessage('Sostituito: $evaluableCondition');
      _addSuccessMessage('Risultato: ${boolResult ? "TRUE" : "FALSE"}');

    } catch (e) {
      _addErrorMessage('Errore valutazione condizione: ${e.toString()}');
    }
  }

  /// Sanifica/normalizza la condizione prima della valutazione
  String _sanitizeCondition(String expression) {
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

  /// Valuta una condizione che può contenere operatori logici e di confronto
  dynamic _evaluateConditionExpression(String expression) {
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
      final left = _evaluateConditionExpression(orSplit[0]);
      final right = _evaluateConditionExpression(orSplit[1]);
      final l = (left is bool) ? left : (left != 0);
      final r = (right is bool) ? right : (right != 0);
      return l || r;
    }

    // 2) AND logico a livello top-level
    final andSplit = _splitAtTopLevel(expr, '&&');
    if (andSplit != null) {
      final left = _evaluateConditionExpression(andSplit[0]);
      final right = _evaluateConditionExpression(andSplit[1]);
      final l = (left is bool) ? left : (left != 0);
      final r = (right is bool) ? right : (right != 0);
      return l && r;
    }

    // 3) NOT logico (unario) all'inizio dell'espressione
    if (expr.startsWith('!')) {
      final inner = _evaluateConditionExpression(expr.substring(1).trim());
      final v = (inner is bool) ? inner : (inner != 0);
      return !v;
    }

    // 4) Confronti (tenere ordinamento: doppi operatori prima dei singoli)
    for (final op in const ['>=', '<=', '==', '!=']) {
      final parts = _splitAtTopLevel(expr, op);
      if (parts != null) {
        final left = _evaluateConditionExpression(parts[0]);
        final right = _evaluateConditionExpression(parts[1]);
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
        final left = _evaluateConditionExpression(parts[0]);
        final right = _evaluateConditionExpression(parts[1]);
        switch (op) {
          case '>':
            return (left is num && right is num && left > right) ? 1 : 0;
          case '<':
            return (left is num && right is num && left < right) ? 1 : 0;
        }
      }
    }

    // 6) Nessun operatore logico/di confronto: valuta come espressione matematica
    return _evaluateMathExpression(expr);
  }

  /// Rimuove una coppia di parentesi esterne se racchiudono interamente l'espressione
  String _stripOuterParentheses(String s) {
    while (s.length >= 2 && s.startsWith('(') && s.endsWith(')')) {
      var depth = 0;
      var enclosesAll = true;
      for (int i = 0; i < s.length; i++) {
        final c = s[i];
        if (c == '(') depth++;
        if (c == ')') {
          depth--;
          if (depth == 0 && i != s.length - 1) {
            // chiude prima della fine, quindi le parentesi esterne non racchiudono tutto
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

  /// Divide l'espressione al primo operatore trovato a livello top-level (fuori da parentesi)
  List<String>? _splitAtTopLevel(String s, String operator) {
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

  String _renderTemplate(String template, Map<String, dynamic> vars) {
    return template.replaceAllMapped(
      RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}'),
      (match) {
        final varName = match.group(1)!;

        if (vars.containsKey(varName)) {
          final value = vars[varName];
          if (value != null && !(value is String && value.isEmpty)) {
            return value.toString();
          }
        }

        return '{$varName}';
      },
    );
  }

  void _addSystemMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.system,
      text: text,
    ));
  }

  void _addInfoMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.info,
      text: text,
    ));
  }

  void _addPrompt(String prompt) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.prompt,
      text: prompt,
    ));
  }

  void _addUserInput(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.userInput,
      text: text,
    ));
  }

  void _addSuccessMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.success,
      text: text,
    ));
  }

  void _addErrorMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.error,
      text: text,
    ));
  }

  void _addOutputMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.output,
      text: text,
    ));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFF3F3F3),
        border: Border(
          top: BorderSide(
            color: theme.resources.dividerStrokeColorDefault,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header della console
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              border: Border(
                bottom: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.terminal,
                  size: 14,
                  color: theme.accentColor.defaultBrushFor(theme.brightness),
                ),
                const SizedBox(width: 8),
                Text(
                  'Console Debug',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.resources.textFillColorPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.trashCan, size: 12),
                  onPressed: () {
                    setState(() {
                      _history.clear();
                      _addSystemMessage('Console pulita');
                    });
                  },
                ),
              ],
            ),
          ),

          // Area di output (storico)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                return _buildConsoleEntry(theme, _history[index]);
              },
            ),
          ),

          // Area di input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              border: Border(
                top: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '>',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.accentColor.defaultBrushFor(theme.brightness),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextBox(
                    controller: _inputController,
                    focusNode: _focusNode,
                    placeholder: _isWaitingForInput
                      ? 'Inserisci valore...'
                      : 'In attesa...',
                    enabled: _isWaitingForInput,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    onSubmitted: _handleInput,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isWaitingForInput
                    ? () => _handleInput(_inputController.text)
                    : null,
                  child: const Text('Invio'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleEntry(FluentThemeData theme, ConsoleEntry entry) {
    Color textColor;
    String prefix = '';

    switch (entry.type) {
      case ConsoleEntryType.system:
        textColor = theme.resources.textFillColorSecondary;
        break;
      case ConsoleEntryType.info:
        textColor = theme.accentColor.defaultBrushFor(theme.brightness);
        prefix = 'ℹ';
        break;
      case ConsoleEntryType.prompt:
        textColor = theme.resources.textFillColorPrimary;
        prefix = '?';
        break;
      case ConsoleEntryType.userInput:
        textColor = theme.brightness == Brightness.dark
          ? Colors.white
          : Colors.black;
        prefix = '>';
        break;
      case ConsoleEntryType.success:
        textColor = Colors.green;
        break;
      case ConsoleEntryType.error:
        textColor = Colors.red;
        prefix = '✗';
        break;
      case ConsoleEntryType.output:
        textColor = theme.brightness == Brightness.dark
          ? const Color(0xFF4EC9B0)
          : const Color(0xFF008080);
        prefix = '▶';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText.rich(
        TextSpan(
          children: [
            if (prefix.isNotEmpty)
              TextSpan(
                text: '$prefix ',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            TextSpan(
              text: entry.text,
              style: TextStyle(
                color: textColor,
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ConsoleEntryType {
  system,
  info,
  prompt,
  userInput,
  success,
  error,
  output,
}

class ConsoleEntry {
  final ConsoleEntryType type;
  final String text;

  ConsoleEntry({
    required this.type,
    required this.text,
  });
}

class ResolvedValue {
  final dynamic value;
  final bool isLiteral;
  final String? error;

  ResolvedValue.success(this.value, {this.isLiteral = false}) : error = null;
  ResolvedValue.error(this.error) : value = null, isLiteral = false;
}
