// ============================================================================
// 🎨 DEBUG ENGINE - PRESENTATION LAYER (Console UI Logic)
// ============================================================================
//
// RESPONSABILITÀ:
// ✅ Formattare messaggi per la console
// ✅ Gestire comandi console (help, clear, vars, etc.)
// ✅ Mostrare informazioni sui nodi
// ❌ NON esegue nodi (delega al DebugBloc)
// ❌ NON accede al repository
// ❌ NON gestisce variabili direttamente
// ❌ NON valuta condizioni
//
// REGOLA D'ORO: Solo presentazione, ZERO logica di business
//
// ============================================================================

import 'package:flutter/foundation.dart'; // ✅ Import per VoidCallback
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:debug_repository/debug_repository.dart';
import 'console_models.dart';
import 'commands/commands.dart';

/// DebugEngine completamente ripulito da logica di business.
/// Si occupa SOLO della presentazione console e delega TUTTO tramite callback.
class DebugEngine {
  final FlowNode currentNode;
  final Function(List<ConsoleEntry>) onHistoryUpdate;
  final VoidCallback? onDebugNext;
  final VoidCallback? onDebugPrev;
  final VoidCallback? onDebugStop;
  final Function(Map<String, dynamic>)? onVariablesUpdate;
  final Function()? getVariables; // ritorna mappa variabili correnti
  final bool isDoWhileReentry;
  final bool isInSubprogram;

  final List<VariableDeclaration> allVariables; // ✅ Dichiarazioni per type-check

  final List<ConsoleEntry> _history = [];
  late final CommandRegistry _commandRegistry;

  ConsoleState _state = ConsoleState.idle;
  String? _currentPrompt;

  /// Set di variabili consentite per l'assegnazione runtime, utilizzato solo nei nodi di tipo Input.
  final Set<String>? allowedAssignmentTargets;

  // 🆕 Guardie per abilitare/disabilitare i comandi di navigazione dalla UI esterna
  final bool Function()? canNext;
  final bool Function()? canPrev;

  DebugEngine({
    required this.currentNode,
    required this.onHistoryUpdate,
    this.onDebugNext,
    this.onDebugPrev,
    this.onDebugStop,
    this.onVariablesUpdate,
    this.getVariables,
    this.isDoWhileReentry = false,
    this.isInSubprogram = false,
    this.allowedAssignmentTargets,
    this.allVariables = const [],
    // 🆕
    this.canNext,
    this.canPrev,
  }) {
    _commandRegistry = CommandRegistry(
      onNext: onDebugNext,
      onPrev: onDebugPrev,
    );

    // Mostra solo informazioni sul nodo corrente
    _showNodeInfo();
  }

  /// Mostra le informazioni del nodo corrente senza eseguirlo.
  /// L'esecuzione è delegata al DebugBloc tramite i comandi.
  void _showNodeInfo() {
    if (currentNode is StartNode) {
      _addInfoMessage('🟢 Nodo Start: ${currentNode.text}');
      _showCurrentPrompt('Scrivi "next" per iniziare l\'esecuzione');

      // 🔴 MODIFICATO: Logica spostata qui
    } else if (currentNode is InputNode) {
      final assignments = (currentNode as InputNode).assignments;
      final names = assignments.map((a) => a.target).toList();
      _addInfoMessage('📥 Nodo Input: ${names.join(', ')}');

      // 🆕 Badge variabili mancanti per runtime assignment (spostato qui)
      try {
        final pending = <String>[];
        if (getVariables != null) {
          final vars = Map<String, dynamic>.from(getVariables!() as Map);
          for (final a in assignments) {
            final expr = a.expression.trim();
            if (expr.isNotEmpty) continue; // non è runtime assignment
            final target = a.target.trim();
            final hasValue = vars.containsKey(target) && vars[target] != null;
            if (!hasValue) pending.add(target);
          }
        }
        if (pending.isNotEmpty) {
          _addInfoMessage('⏳ In attesa input per: ${pending.join(', ')}');
        }
      } catch (_) {}

      _showCurrentPrompt('Inserisci i valori (es: var = 10) e premi "next"');

    } else if (currentNode is OutputNode) {
      _addInfoMessage('📤 Nodo Output: ${currentNode.text}');
      _showCurrentPrompt('Scrivi "next" per eseguire l\'output');

      // 🔴 MODIFICATO: Logica badge rimossa
    } else if (currentNode is AssignmentNode) {
      final assignments = (currentNode as AssignmentNode).assignments;
      final preview = assignments.map((a) => '${a.target} = ${a.expression}').join(', ');
      _addInfoMessage('✏️ Nodo Assegnazione: $preview');

      // (Badge variabili mancanti rimosso da qui)

      _showCurrentPrompt('Scrivi "next" per eseguire le assegnazioni');

    } else if (currentNode is DecisionNode) {
      _addInfoMessage('🔀 Nodo Decisione: ${currentNode.text}');
      _showCurrentPrompt('Scrivi "next" per valutare la condizione');
    } else if (currentNode is WhileNode) {
      _addInfoMessage('🔁 Nodo While: ${currentNode.text}');
      _showCurrentPrompt('Scrivi "next" per valutare la condizione');
    } else if (currentNode is DoWhileNode) {
      if (isDoWhileReentry) {
        _addInfoMessage('🔄 Do-While (controllo condizione): ${currentNode.text}');
        _showCurrentPrompt('Scrivi "next" per valutare la condizione');
      } else {
        _addInfoMessage('🔄 Do-While (prima iterazione): ${currentNode.text}');
        _showCurrentPrompt('Scrivi "next" per entrare nel corpo del ciclo');
      }
    } else if (currentNode is ProcessNode) {
      final processNode = currentNode as ProcessNode;
      _addInfoMessage('⚙️ Nodo Processo: ${processNode.flowchartToCall}');
      if (processNode.arguments.isNotEmpty) {
        _addInfoMessage('   Argomenti: ${processNode.arguments.join(', ')}');
      }
      _showCurrentPrompt('Scrivi "next" per chiamare il sottoprogramma');
    } else if (currentNode is ReturnNode) {
      final returnNode = currentNode as ReturnNode;
      if (returnNode.returnExpression != null) {
        _addInfoMessage('↩️ Nodo Return: ${returnNode.returnExpression}');
      } else {
        _addInfoMessage('↩️ Nodo Return (void)');
      }
      _showCurrentPrompt('Scrivi "next" per ritornare al chiamante');
    } else if (currentNode is EndNode) {
      if (isInSubprogram) {
        _addInfoMessage('🔴 End (sottoprogramma): ritorno al chiamante');
      } else {
        _addInfoMessage('🔴 Nodo End: fine esecuzione');
      }
      _showCurrentPrompt('Scrivi "next" per terminare');
    } else {
      _addInfoMessage('📍 Nodo: ${currentNode.kind.name}');
      _showCurrentPrompt('Scrivi "next" per continuare');
    }

    _state = ConsoleState.completed;
    _notifyUpdate();
  }

  // ==========================================================================
  // 📥 GESTIONE INPUT UTENTE
  // ==========================================================================

  Future<void> handleInput(String input) async {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) return;

    _addUserInput(trimmedInput);

    // 1) Pattern assignment runtime: var = expr
    final assignRE = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$');
    final m = assignRE.firstMatch(trimmedInput);
    if (m != null && getVariables != null && onVariablesUpdate != null) {
      final varName = m.group(1)!;
      final expr = m.group(2)!.trim();

      // ✅ Restringi alle variabili del blocco Input corrente
      if (allowedAssignmentTargets != null) {
        if (!allowedAssignmentTargets!.contains(varName)) {
          _addErrorMessage('"$varName" non fa parte del blocco di input corrente');
          _notifyUpdate();
          return;
        }
      } else {
        _addErrorMessage('Assegnazioni a runtime non consentite in questo nodo');
        _notifyUpdate();
        return;
      }

      try {
        final vars = Map<String, dynamic>.from(getVariables!() as Map);

        // 🔒 Type-check: trova la dichiarazione della variabile target
        VariableDeclaration? decl;
        try {
          decl = allVariables.firstWhere((v) => v.name == varName);
        } catch (_) {
          decl = null;
        }
        if (decl == null) {
          _addErrorMessage('Variabile "$varName" non dichiarata nel flowchart');
          _notifyUpdate();
          return;
        }

        final eval = ExpressionParser.evaluate(expr, vars, targetDeclaration: decl);
        if (!eval.isValid) {
          _addErrorMessage('Errore assegnazione: ${eval.errorMessage ?? 'espressione non valida'}');
          _notifyUpdate();
          return;
        }
        onVariablesUpdate!.call({varName: eval.value});
        _addSuccessMessage('$varName = ${eval.value}');
      } catch (e) {
        _addErrorMessage('Errore assegnazione: ${e.toString()}');
      }
      _state = ConsoleState.completed;
      _notifyUpdate();
      return;
    }

    // 2) Comandi (help, clear, next, prev, ...)
    if (trimmedInput.startsWith('/') || _isCommand(trimmedInput)) {
      final commandInput = trimmedInput.startsWith('/')
          ? trimmedInput.substring(1)
          : trimmedInput;

      await _handleCommand(commandInput);
      return;
    }

    // 3) Non riconosciuto
    _addErrorMessage('Comando non riconosciuto. Usa "help" per vedere i comandi disponibili.');
    _notifyUpdate();
  }

  bool _isCommand(String input) {
    final commandName = input.split(RegExp(r'\s+')).first.toLowerCase();
    return _commandRegistry.findCommand(commandName) != null;
  }

  Future<void> _handleCommand(String commandInput) async {
    _state = ConsoleState.processing;
    _notifyUpdate();

    // 🆕 Prima di delegare al registry, valida i comandi di navigazione rispetto alle guardie
    final parts = commandInput.trim().split(RegExp(r'\s+'));
    final commandName = parts.isNotEmpty ? parts.first.toLowerCase() : '';

    // Blocca NEXT se non consentito dalla UI/Bloc
    if ((commandName == 'next' || commandName == 'n' || commandName == 'forward')) {
      if (canNext != null && canNext!.call() == false) {
        _addSystemMessage('Attendi: è in corso una valutazione o è richiesto un input.');
        _state = ConsoleState.completed;
        _notifyUpdate();
        return;
      }
    }

    // Blocca PREV se non consentito (per coerenza, opzionale)
    if ((commandName == 'prev' || commandName == 'p' || commandName == 'back')) {
      if (canPrev != null && canPrev!.call() == false) {
        _addSystemMessage('Azione non disponibile durante l\'elaborazione.');
        _state = ConsoleState.completed;
        _notifyUpdate();
        return;
      }
    }

    // Il CommandRegistry gestisce i comandi base (help, clear)
    // I comandi di navigazione (next, prev, stop) delegano ai callback
    final context = CommandContext(
      onOutput: (message) => _addInfoMessage(message),
      onError: (message) => _addErrorMessage(message),
      onClearHistory: () {
        _history.clear();
        _addSystemMessage('Console pulita');
      },
      onExit: onDebugStop ?? () {},
      sessionVariables: {}, // Non usato - le variabili sono nel DebugBloc
      projectRepo: null, // Non usato - nessun accesso diretto al repo
      flowchartId: '', // Non usato
    );

    final result = await _commandRegistry.executeCommand(commandInput, context);

    if (!result.success && result.message != null) {
      _addErrorMessage(result.message!);
    } else if (result.success && result.message != null) {
      _addSuccessMessage(result.message!);
    }

    _state = ConsoleState.completed;
    _notifyUpdate();
  }

  // ==========================================================================
  // 📝 GESTIONE MESSAGGI CONSOLE
  // ==========================================================================

  void _addInfoMessage(String message) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.info, text: message));
  }

  void _addSuccessMessage(String message) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.success, text: message));
  }

  void _addErrorMessage(String message) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.error, text: message));
  }

  void _addSystemMessage(String message) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.system, text: message));
  }

  void _addUserInput(String input) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.userInput, text: input));
  }

  void _showCurrentPrompt([String? customPrompt]) {
    _currentPrompt = customPrompt ?? 'Scrivi "next" per continuare, o "help" per i comandi:';
  }

  void _notifyUpdate() {
    onHistoryUpdate(_history);
  }

  // ==========================================================================
  // 🔍 QUERY
  // ==========================================================================

  List<ConsoleEntry> get history => List.unmodifiable(_history);
  ConsoleState get state => _state;
  String? get currentPrompt => _currentPrompt;
  bool get isWaitingForInput => _state == ConsoleState.waitingForInput;

  // ==========================================================================
  // 🆕 METODI PER AGGIORNARE LA CONSOLE DA EVENTI ESTERNI
  // ==========================================================================

  /// Chiamato dal widget quando il DebugBloc emette un nuovo stato
  /// dopo l'esecuzione di un nodo.
  void showExecutionResult({
    required bool success,
    String? message,
    Map<String, dynamic>? updatedVariables,
  }) {
    if (success) {
      if (message != null && message.isNotEmpty) {
        _addSuccessMessage(message);
      }
      if (updatedVariables != null && updatedVariables.isNotEmpty) {
        _addInfoMessage('Variabili aggiornate: ${updatedVariables.keys.join(', ')}');
      }
    } else {
      _addErrorMessage(message ?? 'Errore durante l\'esecuzione');
    }

    _state = ConsoleState.completed;
    _showCurrentPrompt();
    _notifyUpdate();
  }

  /// Mostra il risultato di una decisione
  void showDecisionResult({
    required bool result,
    required String condition,
  }) {
    _addInfoMessage('Condizione: $condition');
    _addSuccessMessage('Risultato: ${result ? '✓ VERO' : '✗ FALSO'}');
    _state = ConsoleState.completed;
    _showCurrentPrompt();
    _notifyUpdate();
  }

  /// Mostra messaggi di errore da eventi esterni
  void showError(String message) {
    _addErrorMessage(message);
    _state = ConsoleState.error;
    _notifyUpdate();
  }
}