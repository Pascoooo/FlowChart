import 'package:flutter/foundation.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'console_models.dart';
import '../../../../../config/services/expression_parser.dart';
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
  // NEW: indica se stiamo entrando nel do-while per la prima volta (true) o rivalutando (false)
  final bool isDoWhileReentry;
  // 🆕 NUOVO: callback per entrare in un sottoprogramma
  final void Function(ProcessNode)? onStepIntoSubprogram;
  // 🆕 NUOVO: callback per tornare dal sottoprogramma con il valore di ritorno
  final void Function({dynamic returnValue})? onReturnFromSubprogram;
  // 🆕 NUOVO: indica se siamo in un sottoprogramma (call stack non vuoto)
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
    this.isDoWhileReentry = false, // NEW: default false = prima entrata
    this.onStepIntoSubprogram, // 🆕 NUOVO
    this.onReturnFromSubprogram, // 🆕 NUOVO
    this.isInSubprogram = false, // 🆕 NUOVO
  }) {
    // 🆕 NUOVO: Wrapper per onDebugNext che gestisce ProcessNode
    VoidCallback? wrappedOnNext;
    if (onDebugNext != null) {
      wrappedOnNext = () {
        // Se siamo su un ProcessNode con un sottoprogramma configurato, triggera step-into
        if (currentNode is ProcessNode) {
          final processNode = currentNode as ProcessNode;
          if (processNode.flowchartToCall.isNotEmpty && onStepIntoSubprogram != null) {
            // Chiama il callback per entrare nel sottoprogramma
            onStepIntoSubprogram!(processNode);
            return; // Non chiamare onDebugNext normale
          }
        }
        // Altrimenti, procedi normalmente
        onDebugNext!();
      };
    }

    _commandRegistry = CommandRegistry(
      onNext: wrappedOnNext,
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
      // delega a finalize
      await _initializeOutputNode(currentNode as OutputNode);
    } else if (currentNode is ProcessNode) {
      // NEW: gestione completa del nodo di processo (chiamata a sottoprogramma)
      await _initializeProcessNode(currentNode as ProcessNode);
    } else if (currentNode is DecisionNode) {
      // Valuta subito la condizione del nodo Decision
      await _evaluateDecisionNode(currentNode as DecisionNode);
    } else if (currentNode is WhileNode) {
      // Valuta subito la condizione del ciclo pre-condizionale (while)
      await _evaluateWhileNode(currentNode as WhileNode);
    } else if (currentNode is DoWhileNode) {
      // Valuta subito la condizione del ciclo post-condizionale (do-while)
      // Uniformiamo la logica a Decision: true/false determinano il ramo
      await _evaluateDoWhileNode(currentNode as DoWhileNode);
    } else {
      _initializeGenericNode();
    }
    _notifyUpdate();
  }

  /// Inizializza il nodo START
  void _initializeStartNode() {
    _addInfoMessage('Esecuzione avviata');
    _state = ConsoleState.completed;
    // Non auto-avanzare: l'utente decide il passo successivo
  }

  /// Inizializza il nodo END
  void _initializeEndNode() async {
    _addSuccessMessage('Esecuzione terminata');

    // 🆕 NUOVO: Se siamo in un sottoprogramma, recupera il valore di ritorno
    if (isInSubprogram && onReturnFromSubprogram != null) {
      try {
        // Recupera il valore della variabile di ritorno (se prevista)
        final sessionVars = await projectRepo.getDebugVariables(
          projectId: flowchartId,
        );

        // Cerca una variabile dichiarata come OUTPUT (che rappresenta il valore di ritorno)
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

  /// Inizializza il nodo INPUT
  Future<void> _initializeInputNode(InputNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(
        projectId: flowchartId,
      );

      // Verifica che tutte le variabili di input siano dichiarate nel flowchart
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

      // Crea le variabili mancanti nella tabella di debug con valori placeholder
      final toCreate = <String, dynamic>{};
      for (final varName in inputVarNames) {
        if (!sessionVars.containsKey(varName)) {
          final varDecl = allVariables.firstWhere((v) => v.name == varName);
          toCreate[varName] = _getInitialValueForType(varDecl.dataType);
        }
      }

      // Se ci sono variabili da creare, creale nella tabella
      if (toCreate.isNotEmpty) {
        await projectRepo.updateDebugVariables(
          projectId: flowchartId,
          variables: toCreate,
        );
      }

      // Costruisci il messaggio con solo i nomi delle variabili (senza valori)
      final varList = inputVarNames.join(', ');

      _addInfoMessage('Acquisiti in input: $varList');
      _state = ConsoleState.completed;
    } catch (e) {
      _addErrorMessage('Errore durante l\'acquisizione delle variabili di input: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }

  /// Restituisce un valore iniziale appropriato per il tipo di dato specificato
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

      // Verifica che tutte le variabili di destinazione siano DICHIARATE nella workarea
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

      // Separa variabili per scope
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

      // Non creare più automaticamente variabili OUTPUT/LOCAL mancanti
      // Se un assegnamento proverà ad aggiornare variabili non presenti, il repository
      // creerà l'entry solo se la variabile è dichiarata e il tipo è compatibile.

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
    // Non auto-avanzare: richiedi esplicitamente Next
    _showCurrentPrompt('Scrivi "next" per continuare');
    _notifyUpdate();
  }

  /// Nodo generico: stampa informazioni minime e completa subito
  void _initializeGenericNode() {
    _addInfoMessage('Nodo non interattivo: procedo al successivo');
    _state = ConsoleState.completed;
    // Non auto-avanzare, lasciamo il controllo all'utente
    _showCurrentPrompt('Scrivi "next" per continuare');
  }

  /// Fallback per avanzare quando viene richiesto il "prossimo" senza coda variabili
  Future<void> _promptNextVariable() async {
    // Completa il nodo corrente ma non chiama onCommandExecuted qui.
    _state = ConsoleState.completed;
    // L'avanzamento vero e proprio è demandato al comando /next (CommandRegistry)
  }

  /// Renderizza il messaggio di Output sostituendo i placeholder {var}
  Future<void> _finalizeOutputNode(OutputNode node) async {
    final sessionVars = await projectRepo.getDebugVariables(
      projectId: flowchartId,
    );

    // Verifica che tutte le variabili richieste abbiano un valore valido
    for (final vName in node.variables) {
      final v = sessionVars[vName];
      if (v == null || (v is String && v.isEmpty)) {
        throw StateError('Variabile "$vName" non ha un valore assegnato');
      }
    }

    String rendered = node.template;
    for (final vName in node.variables) {
      final v = sessionVars[vName];
      rendered = rendered.replaceAll('{$vName}', v.toString());
    }

    _addOutputMessage(rendered);
    _state = ConsoleState.completed;
    // Non auto-avanzare
    _showCurrentPrompt('Scrivi "next" per continuare');
  }

  /// Inizializza un nodo Output (wrapper senza auto-avanzamento)
  Future<void> _initializeOutputNode(OutputNode node) async {
    try {
      await _finalizeOutputNode(node);
    } catch (e) {
      _addErrorMessage('Errore nel nodo Output: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }

  // ========== Metodi di utilità / logging ==========
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
    // default: string
    return value?.toString();
  }

  // ========== Valutazione condizioni ==========
  Future<void> _evaluateDecisionNode(DecisionNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(projectId: flowchartId);
      final result = _evaluateClauses(node.clauses, node.logicalJoin, sessionVars);
      _addInfoMessage('Decision: condizione = ${result ? 'TRUE' : 'FALSE'}');
      _state = ConsoleState.completed;
      onDecisionEvaluated?.call(node.id, result);
      // Non auto-avanzare: attendi azione utente (Next)
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
    // Valuta SEMPRE la condizione quando si arriva al nodo do-while
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
      if (!c.isRightLiteral && !sessionVars.containsKey(c.rightOperand)) {
        // Se il destro è variabile ma non esiste, trattiamo come null
      }
      dynamic right;
      if (c.isRightLiteral) {
        right = _parseLiteral(c.rightOperand);
      } else {
        right = sessionVars[c.rightOperand];
      }
      switch (c.operator) {
        case '==':
          return _compareEq(left, right);
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
    return s; // fallback stringa
  }

  // ======================================================
  // NEW: Gestione del nodo di PROCESSO (chiamata sottoprogramma)
  // ======================================================
  Future<void> _initializeProcessNode(ProcessNode node) async {
    try {
      final sessionVars = await projectRepo.getDebugVariables(projectId: flowchartId);

      // 1) Informazioni sulla chiamata
      final callName = (node.flowchartToCall.isNotEmpty) ? node.flowchartToCall : '(nessuna funzione configurata)';
      _addInfoMessage('Processo: ${callName}');

      // 2) Valuta e mostra gli argomenti (se presenti)
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

      // 3) 🆕 NUOVO: Se c'è una funzione configurata, triggera lo step-into automatico
      if (node.flowchartToCall.isNotEmpty) {
        _addInfoMessage('Premi "next" per entrare nel sottoprogramma "${callName}"');
        _state = ConsoleState.completed;
        _showCurrentPrompt('Scrivi "next" per continuare');
        return;
      }

      // 4) Gestione del risultato della chiamata (se previsto) - SOLO se non entriamo nel sottoprogramma
      if (node.resultTarget != null && node.resultTarget!.trim().isNotEmpty) {
        final resultVar = node.resultTarget!.trim();

        // Verifica dichiarazione
        final decl = allVariables.firstWhere(
          (v) => v.name == resultVar,
          orElse: () => VariableDeclaration(name: resultVar, dataType: 'string', scope: VariableScope.local),
        );
        final isDeclared = allVariables.any((v) => v.name == resultVar);
        if (!isDeclared) {
          _addErrorMessage('Variabile di risultato "$resultVar" non dichiarata nella workarea');
          _state = ConsoleState.error;
          return;
        }

        // Assicura l'esistenza nelle variabili di sessione (se manca, crea un placeholder)
        if (!sessionVars.containsKey(resultVar)) {
          final initial = _getInitialValueForType(decl.dataType);
          await projectRepo.updateDebugVariables(
            projectId: flowchartId,
            variables: {resultVar: initial},
          );
        }

        _addInfoMessage('Il risultato sarà assegnato automaticamente a "$resultVar" al ritorno dal sottoprogramma');
        _state = ConsoleState.completed;
        _showCurrentPrompt('Scrivi "next" per continuare');
        return;
      }

      // 5) Se non c'è resultTarget, completa semplicemente la chiamata informativa
      _state = ConsoleState.completed;
      _showCurrentPrompt('Scrivi "next" per continuare');
    } catch (e) {
      _addErrorMessage('Errore nel nodo Processo: ${e.toString()}');
      _state = ConsoleState.error;
    }
  }
}
