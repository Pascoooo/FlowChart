import 'package:flutter/foundation.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'console_models.dart';
import '../../../../../config/services/expression_parser.dart';
import 'commands/commands.dart';

class DebugEngine {
  final FlowNode currentNode;
  final String flowchartId;
  final dynamic projectRepo;
  final List<VariableDeclaration> allVariables;
  final Function(List<ConsoleEntry>) onHistoryUpdate;
  final VoidCallback onCommandExecuted;
  final VoidCallback onDebugExit;
  final VoidCallback? onDebugNext;
  final VoidCallback? onDebugPrev;
  final void Function(String nodeId, bool result)? onDecisionEvaluated;
  final bool isDoWhileReentry;
  final void Function(ProcessNode)? onStepIntoSubprogram;
  final void Function({dynamic returnValue})? onReturnFromSubprogram;
  final bool isInSubprogram;

  final List<ConsoleEntry> _history = [];
  late final CommandRegistry _commandRegistry;

  ConsoleState _state = ConsoleState.idle;
  String? _currentPrompt;
  String? _currentVariable;

  DebugEngine({
    required this.currentNode,
    required this.flowchartId,
    required this.projectRepo,
    required this.allVariables,
    required this.onHistoryUpdate,
    required this.onCommandExecuted,
    required this.onDebugExit,
    this.onDebugNext,
    this.onDebugPrev,
    this.onDecisionEvaluated,
    this.isDoWhileReentry = false,
    this.onStepIntoSubprogram,
    this.onReturnFromSubprogram,
    this.isInSubprogram = false,
  }) {
    // Il wrapper è stato rimosso. La logica è ora centralizzata nel BLoC.
    _commandRegistry = CommandRegistry(
      onNext: onDebugNext, // Usa direttamente la callback passata
      onPrev: onDebugPrev,
    );

    _initializeNodeByType();
  }

  Future<void> _initializeNodeByType() async {
    if (currentNode is StartNode) {
      _initializeStartNode();
    } else if (currentNode is EndNode) {
      _initializeEndNode();
    } else if (currentNode is InputNode) {
      await _initializeInputNode(currentNode as InputNode);
    } else if (currentNode is AssignmentNode) {
      await _initializeAssignmentNode(currentNode as AssignmentNode);
    } else if (currentNode is OutputNode) {
      await _initializeOutputNode(currentNode as OutputNode);
    } else if (currentNode is ProcessNode) {
      await _initializeProcessNode(currentNode as ProcessNode);
    } else if (currentNode is DecisionNode) {
      await _evaluateDecisionNode(currentNode as DecisionNode);
    } else if (currentNode is WhileNode) {
      await _evaluateWhileNode(currentNode as WhileNode);
    } else if (currentNode is DoWhileNode) {
      await _evaluateDoWhileNode(currentNode as DoWhileNode);
    } else {
      _initializeGenericNode();
    }
    _notifyUpdate();
  }

  void _initializeStartNode() {
    _addInfoMessage('Esecuzione avviata');
    _state = ConsoleState.completed;
  }

  void _initializeEndNode() async {
    _addSuccessMessage('Esecuzione terminata');

    if (isInSubprogram && onReturnFromSubprogram != null) {
      try {
        final sessionVars = await projectRepo.getDebugVariables(
          projectId: flowchartId,
        );

        final returnVar = allVariables.where((v) => v.scope == VariableScope.output).firstOrNull;

        dynamic returnValue;
        if (returnVar != null && sessionVars.containsKey(returnVar.name)) {
          returnValue = sessionVars[returnVar.name];
          _addInfoMessage('Valore di ritorno: ${returnVar.name} = $returnValue');
        } else {
          _addInfoMessage('Nessun valore di ritorno (void)');
        }

        _addInfoMessage('Premi "next" per tornare al chiamante');
        _state = ConsoleState.completed;
        _showCurrentPrompt('Scrivi "next" per continuare');
        return;
      } catch (e) {
        _addErrorMessage('Errore nel recupero del valore di ritorno: ${e.toString()}');
      }
    }

    _state = ConsoleState.completed;
    _showCurrentPrompt('Scrivi "next" per continuare');
  }

  Future<void> _initializeInputNode(InputNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      final inputVarNames = node.targetVariables;
      final undeclared = inputVarNames.where(
              (v) => !allVariables.any((decl) => decl.name == v)
      ).toList();

      if (undeclared.isNotEmpty) {
        _addErrorMessage(
            'ERRORE: Le seguenti variabili non sono dichiarate nel flowchart: ${undeclared.join(', ')}'
        );
        _state = ConsoleState.error;
        return;
      }

      final toCreate = <String, dynamic>{};
      for (final varName in inputVarNames) {
        if (!sessionVars.containsKey(varName)) {
          final varDecl = allVariables.firstWhere((v) => v.name == varName);
          toCreate[varName] = _getInitialValueForType(varDecl.dataType);
        }
      }

      if (toCreate.isNotEmpty) {
        await projectRepo.updateDebugVariables(
          projectId: flowchartId,
          variables: toCreate,
        );
      }

      final varList = inputVarNames.join(', ');

      _addInfoMessage('Acquisiti in input: $varList');
      _state = ConsoleState.completed;
    } catch (e) {
      _addErrorMessage('Errore durante l\'acquisizione delle variabili di input: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }

  dynamic _getInitialValueForType(String dataType) {
    final type = dataType.toLowerCase();
    switch (type) {
      case 'int':
      case 'integer':
        return 0;
      case 'double':
      case 'float':
      case 'number':
        return 0.0;
      case 'bool':
      case 'boolean':
        return false;
      case 'string':
      default:
        return '';
    }
  }

  List<ConsoleEntry> get history => List.unmodifiable(_history);
  ConsoleState get state => _state;
  String? get currentPrompt => _currentPrompt;
  bool get isWaitingForInput => _state == ConsoleState.waitingForInput;

  Future<void> handleInput(String input) async {
    final trimmedInput = input.trim();

    if (trimmedInput.startsWith('/') || _isCommand(trimmedInput)) {
      await _handleCommand(trimmedInput.startsWith('/')
          ? trimmedInput.substring(1)
          : trimmedInput);
      return;
    }

    if (!isWaitingForInput) {
      _addErrorMessage('Non in attesa di input. Usa "help" per vedere i comandi disponibili.');
      _notifyUpdate();
      return;
    }

    _addUserInput(trimmedInput);

    if (trimmedInput.isEmpty) {
      _addErrorMessage('Input vuoto non valido');
      _showCurrentPrompt();
      _notifyUpdate();
      return;
    }

    if (currentNode is AssignmentNode) {
      await _handleAssignmentInput(trimmedInput);
      return;
    }

    if (_currentVariable == null) {
      _addErrorMessage('Errore: nessuna variabile corrente impostata');
      _notifyUpdate();
      return;
    }

    if (trimmedInput.toLowerCase() == 'next') {
      _addInfoMessage('Mantengo il valore corrente per $_currentVariable');
      await _promptNextVariable();
      _notifyUpdate();
      return;
    }

    _state = ConsoleState.processing;
    _notifyUpdate();

    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      final resolved = ExpressionParser.evaluate(trimmedInput, sessionVars);

      if (!resolved.isValid) {
        _addErrorMessage(resolved.errorMessage ?? 'Errore valutazione');
        _showCurrentPrompt();
        _state = ConsoleState.waitingForInput;
        _notifyUpdate();
        return;
      }

      if (!sessionVars.containsKey(_currentVariable!)) {
        _addErrorMessage(
          'ERRORE RUNTIME: La variabile "$_currentVariable" non è presente nelle variabili di sessione',
        );
        _addInfoMessage('Variabili di sessione disponibili: ${sessionVars.keys.join(', ')}');
        _showCurrentPrompt();
        _state = ConsoleState.waitingForInput;
        _notifyUpdate();
        return;
      }

      final varDecl = allVariables.firstWhere(
            (v) => v.name == _currentVariable!,
        orElse: () => VariableDeclaration(
          name: _currentVariable!,
          dataType: 'string',
          scope: VariableScope.local,
        ),
      );

      final convertedValue = _convertToType(resolved.value, varDecl.dataType);

      await projectRepo.updateDebugVariables(
        projectId: flowchartId,
        variables: {_currentVariable!: convertedValue},
      );

      _addSuccessMessage('$_currentVariable = $convertedValue (salvato)');

      await _promptNextVariable();
    } catch (e) {
      _addErrorMessage('Errore: ${e.toString()}');
      _showCurrentPrompt();
      _state = ConsoleState.waitingForInput;
    }

    _notifyUpdate();
  }

  bool _isCommand(String input) {
    final commandName = input.split(RegExp(r'\s+')).first.toLowerCase();
    return _commandRegistry.findCommand(commandName) != null;
  }

  Future<void> _handleCommand(String commandInput) async {
    _addUserInput('/$commandInput');

    final context = CommandContext(
      onOutput: (message) => _addInfoMessage(message),
      onError: (message) => _addErrorMessage(message),
      onClearHistory: () {
        _history.clear();
        _addSystemMessage('Console pulita');
      },
      onExit: onDebugExit,
      sessionVariables: {},
      projectRepo: projectRepo,
      flowchartId: flowchartId,
    );

    final result = await _commandRegistry.executeCommand(commandInput, context);

    if (!result.success && result.message != null) {
      _addErrorMessage(result.message!);
    } else if (result.success && result.message != null) {
      _addSuccessMessage(result.message!);
    }

    _notifyUpdate();
  }

  Future<void> _initializeAssignmentNode(AssignmentNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      final targets = node.assignments.map((a) => a.target).toList();

      final notDeclared = <String>[];
      for (final t in targets) {
        final exists = allVariables.any((v) => v.name == t);
        if (!exists) notDeclared.add(t);
      }
      if (notDeclared.isNotEmpty) {
        for (final v in notDeclared) {
          _addErrorMessage('Variabile "$v" non dichiarata nella workarea');
        }
        _state = ConsoleState.error;
        _notifyUpdate();
        return;
      }

      final inputVars = <String>[];
      final outputAndLocalVars = <String>[];

      for (final target in targets) {
        final varDecl = allVariables.firstWhere((v) => v.name == target);
        if (varDecl.scope == VariableScope.input) {
          inputVars.add(target);
        } else {
          outputAndLocalVars.add(target);
        }
      }

      final missingInputVars = inputVars.where((v) => !sessionVars.containsKey(v)).toList();

      if (missingInputVars.isNotEmpty) {
        for (final m in missingInputVars) {
          _addErrorMessage('Variabile di INPUT "$m" non presente nelle variabili di sessione');
        }
        _addInfoMessage('Le variabili di INPUT devono essere acquisite tramite un nodo Input prima di essere assegnate');
        _addInfoMessage('Inserisci un nodo Input prima di questo blocco di assegnazione');
        _state = ConsoleState.error;
        return;
      }

      bool hasAssignmentError = false;

      for (final assignment in node.assignments) {
        final target = assignment.target;
        final expr = assignment.expression.trim();
        if (expr.isEmpty) continue;
        if (RegExp(r'\{[a-zA-Z_][a-zA-Z0-9_]*\}').hasMatch(expr)) continue;

        final resolved = ExpressionParser.evaluate(expr, sessionVars);
        if (!resolved.isValid) {
          _addErrorMessage('Assegnazione "$target": ${resolved.errorMessage}');
          hasAssignmentError = true;
          continue;
        }

        final varDecl = allVariables.firstWhere((v) => v.name == target);

        try {
          final converted = _convertToType(resolved.value, varDecl.dataType);
          await projectRepo.updateDebugVariables(
            projectId: flowchartId,
            variables: {target: converted},
          );
          sessionVars[target] = converted;
          _addSuccessMessage('$target = $converted (da flowchart)');
        } catch (e) {
          _addErrorMessage('Assegnazione "$target": ${e.toString()}');
          hasAssignmentError = true;
        }
      }

      final updatedVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      for (final assignment in node.assignments) {
        final target = assignment.target;
        final expr = assignment.expression.trim();
        if (expr.isEmpty) continue;
        if (!RegExp(r'\{[a-zA-Z_][a-zA-Z0-9_]*\}').hasMatch(expr)) continue;

        final resolved = ExpressionParser.evaluate(expr, updatedVars);
        if (!resolved.isValid) {
          _addErrorMessage('Assegnazione "$target": ${resolved.errorMessage}');
          hasAssignmentError = true;
          continue;
        }

        final varDecl = allVariables.firstWhere((v) => v.name == target);

        try {
          final converted = _convertToType(resolved.value, varDecl.dataType);
          await projectRepo.updateDebugVariables(
            projectId: flowchartId,
            variables: {target: converted},
          );
          updatedVars[target] = converted;
          _addSuccessMessage('$target = $converted (da flowchart)');
        } catch (e) {
          _addErrorMessage('Assegnazione "$target": ${e.toString()}');
          hasAssignmentError = true;
        }
      }

      if (hasAssignmentError) {
        _addInfoMessage('Sono presenti errori nelle assegnazioni del flowchart: correggi le variabili mancanti o di tipo errato');
      }

      _showAssignmentPrompt();
      _state = ConsoleState.waitingForInput;
    } catch (e) {
      _addErrorMessage('Errore accesso variabili: ${e.toString()}');
      _state = ConsoleState.error;
    }

    _notifyUpdate();
  }

  Future<void> _handleAssignmentInput(String input) async {
    final node = currentNode as AssignmentNode;
    final targets = node.assignments.map((a) => a.target).toList();

    if (input.toLowerCase() == 'next') {
      await _finalizeAssignmentNode();
      return;
    }

    final match = RegExp(r'^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$').firstMatch(input);
    if (match == null) {
      _addErrorMessage('Formato non valido. Usa es.: nome = 123 oppure nome = {x} + 2');
      _showAssignmentPrompt();
      _notifyUpdate();
      return;
    }

    final varName = match.group(1)!;
    final expr = match.group(2)!.trim();

    if (!targets.contains(varName)) {
      _addErrorMessage('Variabile "$varName" non presente in questo blocco di assegnazione');
      _addInfoMessage('Variabili disponibili: ${targets.join(', ')}');
      _showAssignmentPrompt();
      _notifyUpdate();
      return;
    }

    _state = ConsoleState.processing;
    _notifyUpdate();

    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      final resolved = ExpressionParser.evaluate(expr, sessionVars);

      if (!resolved.isValid) {
        _addErrorMessage('Assegnazione "$varName": ${resolved.errorMessage ?? 'Errore valutazione'}');
        _state = ConsoleState.waitingForInput;
        _showAssignmentPrompt();
        _notifyUpdate();
        return;
      }

      final varDecl = allVariables.firstWhere(
            (v) => v.name == varName,
        orElse: () => VariableDeclaration(
          name: varName,
          dataType: 'string',
          scope: VariableScope.local,
        ),
      );

      final convertedValue = _convertToType(
        resolved.value,
        varDecl.dataType,
      );

      await projectRepo.updateDebugVariables(
        projectId: flowchartId,
        variables: {varName: convertedValue},
      );

      _addSuccessMessage('$varName = $convertedValue (salvato)');
      _state = ConsoleState.waitingForInput;
      _showAssignmentPrompt();
    } catch (e) {
      _addErrorMessage('Errore: ${e.toString()}');
      _state = ConsoleState.waitingForInput;
      _showAssignmentPrompt();
    }

    _notifyUpdate();
  }

  void _showAssignmentPrompt() {
    _addSystemMessage('');
    _addInfoMessage('Scrivi un\'assegnazione nella forma: nome = valore oppure nome = espressione (puoi usare {variabile}). Scrivi "next" per continuare');
  }

  Future<void> _finalizeAssignmentNode() async {
    _state = ConsoleState.processing;
    _notifyUpdate();

    final node = currentNode as AssignmentNode;
    final sessionVars = await projectRepo.getDebugVariables(
      projectId: flowchartId,
    );

    final targets = node.assignments.map((a) => a.target).toList();
    final unassigned = targets.where((t) {
      return !sessionVars.containsKey(t) || sessionVars[t] == null;
    }).toList();

    if (unassigned.isNotEmpty) {
      _addErrorMessage('Impossibile proseguire: le seguenti variabili non sono state assegnate:');
      for (final v in unassigned) {
        _addErrorMessage('  - $v');
      }
      _addInfoMessage('Assegna tutte le variabili richieste prima di continuare');
      _state = ConsoleState.waitingForInput;
      _showAssignmentPrompt();
      _notifyUpdate();
      return;
    }

    _state = ConsoleState.completed;
    _showCurrentPrompt('Scrivi "next" per continuare');
    _notifyUpdate();
  }

  void _initializeGenericNode() {
    _addInfoMessage('Nodo non interattivo: procedo al successivo');
    _state = ConsoleState.completed;
    _showCurrentPrompt('Scrivi "next" per continuare');
  }

  Future<void> _promptNextVariable() async {
    _state = ConsoleState.completed;
  }

  Future<void> _finalizeOutputNode(OutputNode node) async {
    final sessionVars = await projectRepo.getDebugVariables(
      projectId: flowchartId,
    );

    for (final v in node.variables) {
      if (!sessionVars.containsKey(v.name) || sessionVars[v.name] == null) {
        throw StateError('Variabile "${v.name}" non ha un valore assegnato');
      }
    }

    String rendered = node.template;
    for (final v in node.variables) {
      rendered = rendered.replaceAll('{${v.name}}', sessionVars[v.name].toString());
    }

    _addOutputMessage(rendered);
    _state = ConsoleState.completed;
    _showCurrentPrompt('Scrivi "next" per continuare');
  }

  Future<void> _initializeOutputNode(OutputNode node) async {
    try {
      await _finalizeOutputNode(node);
    } catch (e) {
      _addErrorMessage('Errore nel nodo Output: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }

  void _addSystemMessage(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.system, text: text));
  }

  void _addInfoMessage(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.info, text: text));
  }

  void _addSuccessMessage(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.success, text: text));
  }

  void _addErrorMessage(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.error, text: text));
  }

  void _addOutputMessage(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.output, text: text));
  }

  void _addUserInput(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.userInput, text: text));
  }

  void _showCurrentPrompt([String? prompt]) {
    _currentPrompt = prompt ?? _currentPrompt;
    if (_currentPrompt != null && _currentPrompt!.isNotEmpty) {
      _history.add(ConsoleEntry(type: ConsoleEntryType.prompt, text: _currentPrompt!));
    }
  }

  void _notifyUpdate() {
    onHistoryUpdate(List.unmodifiable(_history));
  }

  dynamic _convertToType(dynamic value, String dataType) {
    final type = dataType.toLowerCase();
    if (type == 'int' || type == 'integer') {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.parse(value.toString());
    }
    if (type == 'double' || type == 'float' || type == 'number') {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.parse(value.toString());
    }
    if (type == 'bool' || type == 'boolean') {
      if (value is bool) return value;
      final s = value.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      throw FormatException('Valore booleano non valido: $value');
    }
    return value?.toString();
  }

  Future<void> _evaluateDecisionNode(DecisionNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(projectId: flowchartId);
      final result = _evaluateClauses(node.clauses, node.logicalJoin, sessionVars);
      _addInfoMessage('Decision: condizione = ${result ? 'TRUE' : 'FALSE'}');
      _state = ConsoleState.completed;
      onDecisionEvaluated?.call(node.id, result);
      _showCurrentPrompt('Scrivi "next" per continuare');
    } catch (e) {
      _addErrorMessage('Errore valutazione Decision: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }

  Future<void> _evaluateWhileNode(WhileNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(projectId: flowchartId);
      final result = _evaluateClauses(node.clauses, node.logicalJoin, sessionVars);
      _addInfoMessage('While: condizione = ${result ? 'TRUE (entra nel corpo)' : 'FALSE (esce)'}');
      _state = ConsoleState.completed;
      onDecisionEvaluated?.call(node.id, result);
      _showCurrentPrompt('Scrivi "next" per continuare');
    } catch (e) {
      _addErrorMessage('Errore valutazione While: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }

  Future<void> _evaluateDoWhileNode(DoWhileNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(projectId: flowchartId);
      final result = _evaluateClauses(node.clauses, node.logicalJoin, sessionVars);
      _addInfoMessage('Do-While: condizione = ${result ? 'TRUE (ripete il ciclo)' : 'FALSE (esce)'}');
      _state = ConsoleState.completed;
      onDecisionEvaluated?.call(node.id, result);
      _showCurrentPrompt('Scrivi "next" per continuare');
    } catch (e) {
      _addErrorMessage('Errore valutazione Do-While: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }

  bool _evaluateClauses(List<ConditionClause> clauses, String logicalJoin, Map<String, dynamic> sessionVars) {
    if (clauses.isEmpty) return false;

    bool evalClause(ConditionClause c) {
      dynamic left = sessionVars[c.leftOperand];
      dynamic right;
      if (c.isRightLiteral) {
        right = _parseLiteral(c.rightOperand);
      } else {
        right = sessionVars[c.rightOperand];
      }
      switch (c.operator) {
        case '==':
        case '=':
          return _compareEq(left, right);
        case '!=':
          return !_compareEq(left, right);
        case '>=':
          return _toNum(left) >= _toNum(right);
        case '<=':
          return _toNum(left) <= _toNum(right);
        case '>':
          return _toNum(left) > _toNum(right);
        case '<':
          return _toNum(left) < _toNum(right);
        default:
          throw UnsupportedError('Operatore non supportato: ${c.operator}');
      }
    }

    bool agg(bool a, bool b) => (logicalJoin.toUpperCase() == 'AND') ? (a && b) : (a || b);

    bool acc = evalClause(clauses.first);
    for (int i = 1; i < clauses.length; i++) {
      acc = agg(acc, evalClause(clauses[i]));
    }
    return acc;
  }

  bool _compareEq(dynamic a, dynamic b) {
    if (a is num && b is num) return a == b;
    if (a is bool && b is bool) return a == b;
    return (a?.toString() ?? '') == (b?.toString() ?? '');
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    final s = v?.toString();
    final n = num.tryParse(s ?? '');
    if (n == null) {
      throw FormatException('Valore non numerico: $v');
    }
    return n;
  }

  dynamic _parseLiteral(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if ((s.startsWith('\'') && s.endsWith('\'')) || (s.startsWith('"') && s.endsWith('"'))) {
      return s.substring(1, s.length - 1);
    }
    if (s.toLowerCase() == 'true') return true;
    if (s.toLowerCase() == 'false') return false;
    final n = num.tryParse(s);
    if (n != null) return n;
    return s;
  }

  Future<void> _initializeProcessNode(ProcessNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(projectId: flowchartId);

      final callName = (node.flowchartToCall.isNotEmpty) ? node.flowchartToCall : '(nessuna funzione configurata)';
      _addInfoMessage('Processo: ${callName}');

      if (node.arguments.isNotEmpty) {
        final argValues = <dynamic>[];
        bool argsOk = true;
        for (int i = 0; i < node.arguments.length; i++) {
          final expr = node.arguments[i];
          final res = ExpressionParser.evaluate(expr, sessionVars);
          if (!res.isValid) {
            _addErrorMessage('Argomento ${i + 1}: ${res.errorMessage ?? 'espressione non valida'}');
            argsOk = false;
            continue;
          }
          argValues.add(res.value);
        }
        if (argsOk) {
          _addSuccessMessage('Argomenti valutati: ${argValues.join(', ')}');
        } else {
          _addInfoMessage('Correggi gli argomenti oppure prosegui dopo aver sistemato le variabili mancanti');
        }
      }

      if (node.flowchartToCall.isNotEmpty) {
        _addInfoMessage('Premi "next" per entrare nel sottoprogramma "${callName}"');
        _state = ConsoleState.completed;
        _showCurrentPrompt('Scrivi "next" per continuare');
        return;
      }

      if (node.resultTarget != null && node.resultTarget!.trim().isNotEmpty) {
        final resultVar = node.resultTarget!.trim();

        final isDeclared = allVariables.any((v) => v.name == resultVar);
        if (!isDeclared) {
          _addErrorMessage('Variabile di risultato "$resultVar" non dichiarata nella workarea');
          _state = ConsoleState.error;
          return;
        }

        if (!sessionVars.containsKey(resultVar)) {
          final decl = allVariables.firstWhere((v) => v.name == resultVar);
          final initial = _getInitialValueForType(decl.dataType);
          await projectRepo.updateDebugVariables(
            projectId: flowchartId,
            variables: {resultVar: initial},
          );
        }

        _addInfoMessage('Il risultato sarà assegnato automaticamente a "$resultVar" al ritorno dal sottoprogramma');
      }

      _state = ConsoleState.completed;
      _showCurrentPrompt('Scrivi "next" per continuare');
    } catch (e) {
      _addErrorMessage('Errore nel nodo Processo: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }
}