import 'package:flutter/foundation.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'console_models.dart';
import '../../../../../config/services/expression_parser.dart';
import 'expression_evaluator.dart';
import 'commands/commands.dart';

/// Engine che gestisce la logica di debug per i nodi del flowchart
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
  // NEW: notify decision result to the outside (Bloc) with nodeId
  final void Function(String nodeId, bool result)? onDecisionEvaluated;

  final List<ConsoleEntry> _history = [];
  final List<String> _variablesQueue = [];
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
    this.onDecisionEvaluated, // NEW optional
  }) {
    _commandRegistry = CommandRegistry(
      onNext: onDebugNext,
      onPrev: onDebugPrev,
    );

    // Inizializza il nodo in base al tipo (chiamata asincrona)
    _initializeNodeByType();
  }

  /// Inizializza il nodo in base al tipo e stampa i messaggi appropriati
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
    } else if (currentNode is DecisionNode) {
      // Valuta subito la condizione del nodo Decision
      await _evaluateDecisionNode(currentNode as DecisionNode);
    } else {
      _initializeGenericNode();
    }
    _notifyUpdate();
  }

  /// Inizializza il nodo START
  void _initializeStartNode() {
    _addInfoMessage('Esecuzione avviata');
    _state = ConsoleState.completed;
  }

  /// Inizializza il nodo END
  void _initializeEndNode() {
    _addSuccessMessage('Esecuzione terminata');
    _state = ConsoleState.completed;
  }

  /// Inizializza il nodo INPUT
  Future<void> _initializeInputNode(InputNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      // Verifica che tutte le variabili di input esistano
      final inputVarNames = node.targetVariables;
      final missing = inputVarNames.where((v) => !sessionVars.containsKey(v)).toList();

      if (missing.isNotEmpty) {
        _addErrorMessage('Impossibile acquisire le variabili di input definite');
        _state = ConsoleState.error;
        return;
      }

      // Costruisci il messaggio con solo i nomi delle variabili (senza valori)
      final varList = inputVarNames.join(', ');

      _addInfoMessage('Acquisiti in input: $varList');
      _state = ConsoleState.completed;
    } catch (e) {
      _addErrorMessage('Impossibile acquisire le variabili di input definite');
      _state = ConsoleState.error;
    }
  }

  // Getters
  List<ConsoleEntry> get history => List.unmodifiable(_history);
  ConsoleState get state => _state;
  String? get currentPrompt => _currentPrompt;
  bool get isWaitingForInput => _state == ConsoleState.waitingForInput;

  /// Gestisce l'input dell'utente
  Future<void> handleInput(String input) async {
    final trimmedInput = input.trim();

    // Controlla se è un comando (inizia con / oppure è un comando noto)
    if (trimmedInput.startsWith('/') || _isCommand(trimmedInput)) {
      await _handleCommand(trimmedInput.startsWith('/')
          ? trimmedInput.substring(1)
          : trimmedInput);
      return;
    }

    // Se non è in attesa di input, ignora
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

    // Gestione specifica per AssignmentNode
    if (currentNode is AssignmentNode) {
      await _handleAssignmentInput(trimmedInput);
      return;
    }

    // Gestione per altri nodi (Decision, ecc.) - modalità sequenziale
    if (_currentVariable == null) {
      _addErrorMessage('Errore: nessuna variabile corrente impostata');
      _notifyUpdate();
      return;
    }

    // Consenti di saltare mantenendo il valore corrente
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

      // Verifica che la variabile target esista nelle variabili di sessione
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

      // Converti nel tipo corretto
      final varDecl = allVariables.firstWhere(
            (v) => v.name == _currentVariable!,
        orElse: () => VariableDeclaration(
          name: _currentVariable!,
          dataType: 'string',
          scope: VariableScope.local,
        ),
      );

      final convertedValue = _convertToType(resolved.value, varDecl.dataType);

      // Salva la variabile immediatamente
      await projectRepo.updateDebugVariables(
        projectId: flowchartId,
        variables: {_currentVariable!: convertedValue},
      );

      _addSuccessMessage('$_currentVariable = $convertedValue (salvato)');

      // Passa alla prossima variabile
      await _promptNextVariable();
    } catch (e) {
      _addErrorMessage('Errore: ${e.toString()}');
      _showCurrentPrompt();
      _state = ConsoleState.waitingForInput;
    }

    _notifyUpdate();
  }

  /// Verifica se l'input è un comando conosciuto
  bool _isCommand(String input) {
    final commandName = input.split(RegExp(r'\s+')).first.toLowerCase();
    return _commandRegistry.findCommand(commandName) != null;
  }

  /// Gestisce l'esecuzione di un comando
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

  /// Inizializza per un nodo Assignment
  Future<void> _initializeAssignmentNode(AssignmentNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      final targets = node.assignments.map((a) => a.target).toList();

      // Separa variabili per scope
      final inputVars = <String>[];
      final outputAndLocalVars = <String>[];

      for (final target in targets) {
        final varDecl = allVariables.firstWhere(
          (v) => v.name == target,
          orElse: () => VariableDeclaration(
            name: target,
            dataType: 'string',
            scope: VariableScope.local,
          ),
        );

        if (varDecl.scope == VariableScope.input) {
          inputVars.add(target);
        } else {
          outputAndLocalVars.add(target);
        }
      }

      // Verifica che le variabili INPUT esistano già (devono passare per un nodo Input prima)
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

      // Per variabili OUTPUT e LAVORO: crea entry se non esistono
      for (final varName in outputAndLocalVars) {
        if (!sessionVars.containsKey(varName)) {
          // Crea la variabile nella sessione con valore null
          await projectRepo.updateDebugVariables(
            projectId: flowchartId,
            variables: {varName: null},
          );
          sessionVars[varName] = null;

          final varDecl = allVariables.firstWhere(
            (v) => v.name == varName,
            orElse: () => VariableDeclaration(
              name: varName,
              dataType: 'string',
              scope: VariableScope.local,
            ),
          );

          final scopeLabel = varDecl.scope == VariableScope.output ? 'OUTPUT' : 'LAVORO';
          _addInfoMessage('Variabile $scopeLabel "$varName" aggiunta alla tabella');
        }
      }

      // Applica le assegnazioni definite nel flowchart (se presenti)
      bool hasAssignmentError = false;

      // Pass 1: Assegnazioni dirette (senza riferimenti)
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

        final varDecl = allVariables.firstWhere(
          (v) => v.name == target,
          orElse: () => VariableDeclaration(
            name: target,
            dataType: 'string',
            scope: VariableScope.local,
          ),
        );

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

      // Pass 2: Assegnazioni con espressioni/dipendenze
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

        final varDecl = allVariables.firstWhere(
          (v) => v.name == target,
          orElse: () => VariableDeclaration(
            name: target,
            dataType: 'string',
            scope: VariableScope.local,
          ),
        );

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
        _addInfoMessage('Sono presenti errori nelle assegnazioni del flowchart: puoi correggere inserendo le assegnazioni mancanti');
      }

      _showAssignmentPrompt();
      _state = ConsoleState.waitingForInput;
    } catch (e) {
      _addErrorMessage('Errore accesso variabili: ${e.toString()}');
      _state = ConsoleState.error;
    }

    _notifyUpdate();
  }

  /// Gestisce l'input specifico per AssignmentNode (modalità libera)
  Future<void> _handleAssignmentInput(String input) async {
    final node = currentNode as AssignmentNode;
    final targets = node.assignments.map((a) => a.target).toList();

    // Se digita "next", procedi al nodo successivo
    if (input.toLowerCase() == 'next') {
      await _finalizeAssignmentNode();
      return;
    }

    // Parsing formato: nomeVariabile = valore/espressione
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

      // Converti nel tipo corretto
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

      // Salva la variabile
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

  /// Mostra il prompt standard per AssignmentNode
  void _showAssignmentPrompt() {
    _addSystemMessage('');
    _addInfoMessage('Scrivi un\'assegnazione nella forma: nome = valore oppure nome = espressione (puoi usare {variabile}). Scrivi "next" per continuare');
  }

  /// Finalizza il blocco Assignment e procedi
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
    onCommandExecuted();
    _notifyUpdate();
  }

  /// Mostra il prompt corrente
  void _showCurrentPrompt() {
    if (_currentPrompt != null) {
      _addPrompt(_currentPrompt!);
    }
  }

  /// Inizializza per un nodo Output
  Future<void> _initializeOutputNode(OutputNode node) async {
    _addSystemMessage('');

    // Prova a stampare immediatamente il messaggio formattato.
    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      // Verifica rapidamente le variabili dichiarate nel nodo (se presenti)
      for (final v in node.variables) {
        if (!sessionVars.containsKey(v.name) || sessionVars[v.name] == null ||
            (sessionVars[v.name] is String && (sessionVars[v.name] as String).isEmpty)) {
          _addErrorMessage('Impossibile stampare il messaggio. La variabile ${v.name} non ha un valore assegnato.');
          _state = ConsoleState.error;
          _notifyUpdate();
          return;
        }
      }

      // Render del template e stampa
      await _finalizeOutputNode(node);
      _state = ConsoleState.completed;
    } catch (e) {
      // Intercetta eccezioni di render (es. variabile non trovata/senza valore)
      final msg = e.toString();
      // Prova a estrarre il nome variabile dall'eccezione
      final match = RegExp(r'Variabile "([^"]+)"').firstMatch(msg);
      if (match != null) {
        final varName = match.group(1);
        _addErrorMessage('Impossibile stampare il messaggio. La variabile $varName non ha un valore assegnato.');
      } else {
        _addErrorMessage('Impossibile stampare il messaggio. $msg');
      }
      _state = ConsoleState.error;
    }
  }

  /// Inizializza per un nodo Decision - valutazione immediata
  Future<void> _evaluateDecisionNode(DecisionNode node) async {
    _addSystemMessage('');
    try {
      if (node.clauses.isNotEmpty) {
        await _evaluateDecisionClauses(node);
      } else {
        // Fallback legacy su stringa condition
        await _evaluateDecisionCondition(node.condition);
      }
      _state = ConsoleState.completed;
      onCommandExecuted();
    } catch (e) {
      _addErrorMessage('Errore valutazione condizione: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }

  /// Finalizza per nodi generici (start, end, process)
  void _initializeGenericNode() {
    _addSystemMessage('');
    _state = ConsoleState.completed;
  }

  /// Mostra il prompt per la prossima variabile
  Future<void> _promptNextVariable() async {
    if (_variablesQueue.isEmpty) {
      await _finalizeNode();
      return;
    }

    final varName = _variablesQueue.removeAt(0);
    _currentVariable = varName;

    final varDecl = allVariables.firstWhere(
          (v) => v.name == varName,
      orElse: () => VariableDeclaration(
        name: varName,
        dataType: 'string',
        scope: VariableScope.local,
      ),
    );

    _currentPrompt = '$varName (${varDecl.dataType})';
    _state = ConsoleState.waitingForInput;

    _addPrompt(_currentPrompt!);
    _notifyUpdate();
  }

  /// Finalizza il nodo corrente
  Future<void> _finalizeNode() async {
    _state = ConsoleState.processing;

    if (currentNode is AssignmentNode) {
      // Verifica che tutte le variabili siano state assegnate
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      final node = currentNode as AssignmentNode;
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
        _notifyUpdate();
        return;
      }

      onCommandExecuted();
    } else if (currentNode is DecisionNode) {
      // Già valutato in _evaluateDecisionNode
      onCommandExecuted();
    }

    _state = ConsoleState.completed;
    _notifyUpdate();
  }

  /// Finalizza un nodo Output renderizzando il template
  Future<void> _finalizeOutputNode(OutputNode node) async {
    final allVars = await projectRepo.getDebugVariables(
      projectId: flowchartId,
    );

    try {
      // Sostituisci {variabile} con i valori
      String rendered = node.template;
      final pattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
      
      rendered = rendered.replaceAllMapped(pattern, (match) {
        final varName = match.group(1)!;
        if (!allVars.containsKey(varName)) {
          throw Exception('Variabile "$varName" non trovata');
        }
        final value = allVars[varName];
        if (value == null) {
          throw Exception('Variabile "$varName" non ha valore');
        }
        return value.toString();
      });

      _addOutputMessage(rendered);
      onCommandExecuted();
    } catch (e) {
      // Mappa l'errore in un messaggio utente coerente
      final msg = e.toString();
      final match = RegExp(r'Variabile "([^"]+)"').firstMatch(msg);
      if (match != null) {
        final varName = match.group(1);
        _addErrorMessage('Impossibile stampare il messaggio. La variabile $varName non ha un valore assegnato.');
      } else {
        _addErrorMessage('Impossibile stampare il messaggio. $msg');
      }
    }
  }

  /// Valuta la condizione di un nodo Decision legacy (stringa)
  Future<void> _evaluateDecisionCondition(String condition) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      // Sostituisci le variabili nella condizione
      String evaluableCondition = condition;
      for (final entry in sessionVars.entries) {
        final key = entry.key;
        final value = entry.value;
        final valueStr = (value is bool)
            ? (value ? 'true' : 'false')
            : value.toString();

        evaluableCondition = evaluableCondition.replaceAll('{$key}', valueStr);
        evaluableCondition = evaluableCondition.replaceAllMapped(
          RegExp('\\b' + RegExp.escape(key) + '\\b'),
              (match) => valueStr,
        );
      }

      evaluableCondition = ExpressionEvaluator.sanitizeCondition(evaluableCondition);
      final result = ExpressionEvaluator.evaluateCondition(evaluableCondition);
      final boolResult = (result is bool) ? result : (result != 0);

      _addInfoMessage('Valutazione condizione: $condition');
      _addInfoMessage('Espressione valutata: $evaluableCondition');
      _addSuccessMessage('Risultato: ${boolResult ? "TRUE" : "FALSE"}');

      // NEW: notify branch evaluation (do not navigate)
      if (onDecisionEvaluated != null) {
        onDecisionEvaluated!(currentNode.id, boolResult);
      }
    } catch (e) {
      _addErrorMessage('Errore valutazione condizione: ${e.toString()}');
    }
  }

  /// Valuta le clausole strutturate del DecisionNode con controlli di tipo
  Future<void> _evaluateDecisionClauses(DecisionNode node) async {
    final sessionVars = await projectRepo.getDebugVariables(projectId: flowchartId);

    bool? aggregate; // inizia come null, poi combina con AND/OR
    final isAnd = node.logicalJoin.toUpperCase() != 'OR';

    for (final clause in node.clauses) {
      // Recupera valore sinistro (variabile obbligatoria)
      final leftName = clause.leftOperand;
      if (!sessionVars.containsKey(leftName) || sessionVars[leftName] == null ||
          (sessionVars[leftName] is String && (sessionVars[leftName] as String).isEmpty)) {
        _addErrorMessage('La variabile $leftName utilizzata nella condizione non ha un valore assegnato.');
        throw StateError('Variabile mancante');
      }
      final leftValue = sessionVars[leftName];
      final leftType = _inferType(leftValue);

      // Recupera valore destro
      dynamic rightValue;
      String rightType;
      if (clause.isRightLiteral) {
        rightValue = _parseLiteral(clause.rightOperand);
        rightType = _inferType(rightValue);
      } else {
        final rightName = clause.rightOperand;
        if (!sessionVars.containsKey(rightName) || sessionVars[rightName] == null ||
            (sessionVars[rightName] is String && (sessionVars[rightName] as String).isEmpty)) {
          _addErrorMessage('La variabile $rightName utilizzata nella condizione non ha un valore assegnato.');
          throw StateError('Variabile destra mancante');
        }
        rightValue = sessionVars[rightName];
        rightType = _inferType(rightValue);
      }

      // Valida compatibilità tipi per operatori di confronto stretti
      final op = clause.operator.trim();
      bool clauseResult;
      try {
        clauseResult = _evaluateOperator(op, leftValue, rightValue, leftType, rightType);
      } on ArgumentError catch (_) {
        _addErrorMessage('Confronto non valido tra il tipo $leftType e il tipo $rightType.');
        throw StateError('Tipi incompatibili');
      }

      // Log minimale per clausola
      _addInfoMessage('Condizione "${clause.toExpression()}" -> ${clauseResult ? 'TRUE' : 'FALSE'}');

      // Aggrega
      if (aggregate == null) {
        aggregate = clauseResult;
      } else {
        aggregate = isAnd ? (aggregate && clauseResult) : (aggregate || clauseResult);
      }
    }

    final boolResult = aggregate ?? false;
    // Messaggio finale
    _addSuccessMessage('Risultato: ${boolResult ? 'TRUE' : 'FALSE'}');

    // NEW: notify branch evaluation (do not navigate)
    if (onDecisionEvaluated != null) {
      onDecisionEvaluated!(currentNode.id, boolResult);
    }
  }

  /// Valuta una singola operazione di confronto con gestione tipi e operatori extra
  bool _evaluateOperator(String op, dynamic left, dynamic right, String leftType, String rightType) {
    final o = op.toLowerCase();

    bool bothNumeric = left is num && right is num;

    switch (o) {
      case '==':
        if (bothNumeric) return (left as num).toDouble() == (right as num).toDouble();
        return left.toString() == right.toString();
      case '!=':
        if (bothNumeric) return (left as num).toDouble() != (right as num).toDouble();
        return left.toString() != right.toString();
      case '>':
        if (!bothNumeric) throw ArgumentError('> richiede numeri');
        return (left as num) > (right as num);
      case '<':
        if (!bothNumeric) throw ArgumentError('< richiede numeri');
        return (left as num) < (right as num);
      case '>=':
        if (!bothNumeric) throw ArgumentError('>= richiede numeri');
        return left >= right;
      case '<=':
        if (!bothNumeric) throw ArgumentError('<= richiede numeri');
        return (left as num) <= (right as num);
      case 'contains':
        final ls = left.toString();
        final rs = right.toString();
        return ls.contains(rs);
      case '!contains':
        final ls2 = left.toString();
        final rs2 = right.toString();
        return !ls2.contains(rs2);
      default:
        throw ArgumentError('Operatore non supportato: $op');
    }
  }

  String _inferType(dynamic v) {
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is bool) return 'bool';
    if (v == null) return 'null';
    return 'string';
  }

  dynamic _parseLiteral(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if ((s.startsWith("'") && s.endsWith("'")) || (s.startsWith('"') && s.endsWith('"'))) {
      return s.substring(1, s.length - 1);
    }
    if (s.toLowerCase() == 'true') return true;
    if (s.toLowerCase() == 'false') return false;
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(s);
    if (asDouble != null) return asDouble;
    return s; // fallback stringa
  }

  /// Pulisce la history
  void clearHistory() {
    _history.clear();
    _addSystemMessage('Console pulita');
    _notifyUpdate();
  }

  // Metodi per aggiungere entry alla history
  void _addSystemMessage(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.system, text: text));
  }

  void _addInfoMessage(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.info, text: text));
  }

  void _addPrompt(String prompt) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.prompt, text: prompt));
  }

  void _addUserInput(String text) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.userInput, text: text));
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

  void _notifyUpdate() {
    onHistoryUpdate(_history);
  }

  /// Converte un valore nel tipo specificato, gestendo eventuali errori di conversione.
  dynamic _convertToType(dynamic value, String targetType) {
    try {
      if (value == null) return null;

      switch (targetType.toLowerCase()) {
        case 'string':
          return value.toString();
        case 'int':
          return int.tryParse(value.toString()) ?? (throw FormatException('Impossibile convertire "$value" in int'));
        case 'double':
          return double.tryParse(value.toString()) ?? (throw FormatException('Impossibile convertire "$value" in double'));
        case 'bool':
          if (value is bool) return value;
          final lowerStr = value.toString().toLowerCase();
          if (lowerStr == 'true' || lowerStr == 'false') {
            return lowerStr == 'true';
          }
          throw FormatException('Impossibile convertire "$value" in bool');
        default:
          throw FormatException('Tipo sconosciuto: $targetType');
      }
    } catch (e) {
      // Gestisci l'errore di conversione qui (es. log, messaggio all'utente, ecc.)
      throw FormatException('Errore di conversione: ${e.toString()}');
    }
  }
}
