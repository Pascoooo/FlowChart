// ============================================================================
// DEBUG ENGINE - PRESENTATION LAYER (Console UI Logic)
// ============================================================================
//
// Responsabilità:
// - Formattare messaggi per la console
// - Mostrare informazioni sui nodi
// - Gestire esclusivamente l'inserimento degli input per i nodi Input
// - Nessuna logica di esecuzione o comandi console
//
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:debug_repository/debug_repository.dart';
import 'console_models.dart';

/// DebugEngine solo-presentazione, usata per mostrare info e raccogliere input runtime.
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

  final List<VariableDeclaration> allVariables;

  final List<ConsoleEntry> _history = [];

  ConsoleState _state = ConsoleState.idle;
  String? _currentPrompt;

  /// Set di variabili consentite per l'assegnazione runtime, utilizzato solo nei nodi Input.
  final Set<String>? allowedAssignmentTargets;

  // Guardie per abilitare/disabilitare i comandi di navigazione dalla UI esterna
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
    this.canNext,
    this.canPrev,
  }) {
    _showNodeInfo();
  }

  /// Mostra informazioni sul nodo corrente. Solo gli Input richiedono inserimento.
  void _showNodeInfo() {
    if (currentNode is InputNode) {
      final assignments = (currentNode as InputNode).assignments;
      final names = assignments.map((a) => a.target).toList();
      _addInfoMessage('Nodo Input: ${names.join(', ')}');

      try {
        final pending = <String>[];
        if (getVariables != null) {
          final vars = Map<String, dynamic>.from(getVariables!() as Map);
          for (final a in assignments) {
            final expr = a.expression.trim();
            if (expr.isNotEmpty) continue;
            final target = a.target.trim();
            final hasValue = vars.containsKey(target) && vars[target] != null;
            if (!hasValue) pending.add(target);
          }
        }
        if (pending.isNotEmpty) {
          _addInfoMessage('In attesa input per: ${pending.join(', ')}');
        }
      } catch (_) {}

      _showCurrentPrompt('Inserisci i valori richiesti (es: var = 10)');
    } else {
      _addInfoMessage('Nodo: ${currentNode.kind.name}');
      _showCurrentPrompt('Nessun input richiesto per questo nodo.');
    }

    _state = ConsoleState.completed;
    _notifyUpdate();
  }

  // ==========================================================================
  // GESTIONE INPUT UTENTE
  // ==========================================================================

  Future<void> handleInput(String input) async {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) return;

    _addUserInput(trimmedInput);

    // Accetta solo assegnazioni runtime nei nodi Input
    final assignRE = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$');
    final match = assignRE.firstMatch(trimmedInput);

    if (match != null && getVariables != null && onVariablesUpdate != null) {
      final varName = match.group(1)!;
      final expr = match.group(2)!.trim();

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

    // Nessun comando: la console serve solo per input dei nodi Input
    _addInfoMessage('Questo nodo non richiede input dalla console.');
    _notifyUpdate();
  }

  // ==========================================================================
  // GESTIONE MESSAGGI CONSOLE
  // ==========================================================================

  void _addInfoMessage(String message) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.info, text: message));
  }

  void _addSuccessMessage(String message) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.success, text: message));
  }

  void _addErrorMessage(String message, {bool blocking = false}) {
    _history.add(ConsoleEntry(
      type: blocking ? ConsoleEntryType.blockingError : ConsoleEntryType.error,
      text: message,
    ));
  }

  void _addSystemMessage(String message) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.system, text: message));
  }

  void _addUserInput(String input) {
    _history.add(ConsoleEntry(type: ConsoleEntryType.userInput, text: input));
  }

  void _showCurrentPrompt([String? customPrompt]) {
    _currentPrompt = customPrompt ?? 'Nessun input richiesto.';
  }

  void _notifyUpdate() {
    onHistoryUpdate(_history);
  }

  // ==========================================================================
  // QUERY
  // ==========================================================================

  List<ConsoleEntry> get history => List.unmodifiable(_history);
  ConsoleState get state => _state;
  String? get currentPrompt => _currentPrompt;
  bool get isWaitingForInput => _state == ConsoleState.waitingForInput;

  // ==========================================================================
  // METODI PER AGGIORNARE LA CONSOLE DA EVENTI ESTERNI
  // ==========================================================================

  void showExecutionResult({
    required bool success,
    String? message,
    Map<String, dynamic>? updatedVariables,
    bool blocking = false,
  }) {
    if (success) {
      if (message != null && message.isNotEmpty) {
        _addSuccessMessage(message);
      }
      if (updatedVariables != null && updatedVariables.isNotEmpty) {
        // Le variabili sono visibili altrove; nessun log aggiuntivo
      }
    } else {
      _addErrorMessage(message ?? 'Errore durante l\'esecuzione', blocking: blocking);
    }

    _state = ConsoleState.completed;
    _showCurrentPrompt();
    _notifyUpdate();
  }

  @deprecated
  void showDecisionResult({
    required bool result,
    required String condition,
  }) {
    _addInfoMessage('Condizione: $condition');
    _addSuccessMessage('Risultato: ${result ? 'VERO' : 'FALSO'}');
    _state = ConsoleState.completed;
    _showCurrentPrompt();
    _notifyUpdate();
  }

  void showError(String message, {bool blocking = false}) {
    _addErrorMessage(message, blocking: blocking);
    _state = ConsoleState.error;
    _notifyUpdate();
  }
}
