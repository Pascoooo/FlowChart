/// Stati del Debug BLoC.
/// Rappresenta i diversi stati del debugging: iniziale, in corso, in attesa input,
/// completato, errore, pausa. DebugInProgress include flag per lock concorrenza (isProcessing).
import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:debug_repository/debug_repository.dart';

abstract class DebugState extends Equatable {
  const DebugState();

  @override
  List<Object?> get props => [];
}

/// Stato iniziale - nessuna sessione attiva
class DebugInitial extends DebugState {
  const DebugInitial();
}

/// Debug in corso
class DebugInProgress extends DebugState {
  final DebugSession session;
  final Flowchart currentFlowchart;
  final Map<String, Flowchart> projectFlowcharts;
  final bool isFirstStep; // Per gestire lo zoom iniziale
  // 🆕 Ultimo risultato di esecuzione (messaggio e variabili aggiornate)
  final String? lastMessage;
  final Map<String, dynamic>? lastUpdatedVariables;
  // 🆕 Flag: esecuzione step in corso (per disabilitare Next/Prev)
  final bool isProcessing;
  // 🆕 Flag: l'ultimo messaggio è un errore
  final bool lastMessageIsError;
  // 🆕 Flag: l'errore è bloccante (true) o warning (false)
  final bool lastMessageIsBlocking;

  const DebugInProgress({
    required this.session,
    required this.currentFlowchart,
    required this.projectFlowcharts,
    this.isFirstStep = false,
    this.lastMessage,
    this.lastUpdatedVariables,
    this.isProcessing = false,
    this.lastMessageIsError = false,
    this.lastMessageIsBlocking = false,
  });

  // ✅ CALCOLATO DINAMICAMENTE - Nessuna duplicazione
  String get currentNodeId {
    // FIX: evita accesso negativo
    if (session.currentIndex < 0) return '';
    if (session.currentIndex >= session.debugPath.length) return '';
    return session.debugPath[session.currentIndex];
  }

  // Getters per compatibilità con il codice esistente
  int get currentStepIndex => session.currentIndex;
  List<String> get executionPath => session.debugPath;
  CallStack get callStack => session.callStack;

  /// Crea una copia dello stato con modifiche selettive.
  DebugInProgress copyWith({
    DebugSession? session,
    Flowchart? currentFlowchart,
    Map<String, Flowchart>? projectFlowcharts,
    bool? isFirstStep,
    String? lastMessage,
    Map<String, dynamic>? lastUpdatedVariables,
    bool? isProcessing,
    bool? lastMessageIsError,
    bool? lastMessageIsBlocking,
  }) {
    return DebugInProgress(
      session: session ?? this.session,
      currentFlowchart: currentFlowchart ?? this.currentFlowchart,
      projectFlowcharts: projectFlowcharts ?? this.projectFlowcharts,
      isFirstStep: isFirstStep ?? this.isFirstStep,
      lastMessage: lastMessage ?? this.lastMessage,
      lastUpdatedVariables: lastUpdatedVariables ?? this.lastUpdatedVariables,
      isProcessing: isProcessing ?? this.isProcessing,
      lastMessageIsError: lastMessageIsError ?? this.lastMessageIsError,
      lastMessageIsBlocking: lastMessageIsBlocking ?? this.lastMessageIsBlocking,
    );
  }

  @override
  List<Object?> get props => [
        session,
        currentFlowchart,
        projectFlowcharts,
        isFirstStep,
        lastMessage,
        lastUpdatedVariables,
        isProcessing,
        lastMessageIsError,
        lastMessageIsBlocking,
      ];
}

/// In attesa di input dall'utente (es. decisione, assignment)
class DebugAwaitingInput extends DebugState {
  final DebugSession session;
  final Flowchart currentFlowchart;
  final String promptMessage;
  final Map<String, Flowchart> projectFlowcharts;
  final Set<String> targets;

  const DebugAwaitingInput({
    required this.session,
    required this.currentFlowchart,
    required this.promptMessage,
    required this.projectFlowcharts,
    this.targets = const {},
  });

  // ✅ CALCOLATO DINAMICAMENTE
  String get currentNodeId {
    // FIX: evita accesso negativo
    if (session.currentIndex < 0) return '';
    if (session.currentIndex >= session.debugPath.length) return '';
    return session.debugPath[session.currentIndex];
  }

  @override
  List<Object?> get props => [
        session,
        currentFlowchart,
        promptMessage,
        projectFlowcharts,
        targets,
      ];
}

/// Esecuzione completata
class DebugCompleted extends DebugState {
  final String message;

  const DebugCompleted({this.message = 'Esecuzione completata'});

  @override
  List<Object?> get props => [message];
}

/// Errore durante il debug (classificato)
class DebugError extends DebugState {
  final String message;
  final bool isBlocking;

  const DebugError(this.message, {this.isBlocking = true});

  @override
  List<Object?> get props => [message, isBlocking];
}

/// Pausa (per step-by-step)
class DebugPaused extends DebugState {
  final DebugSession session;
  final Flowchart currentFlowchart;
  final String currentNodeId;
  final Map<String, Flowchart> projectFlowcharts;

  const DebugPaused({
    required this.session,
    required this.currentFlowchart,
    required this.currentNodeId,
    required this.projectFlowcharts,
  });

  @override
  List<Object?> get props => [
        session,
        currentFlowchart,
        currentNodeId,
        projectFlowcharts,
      ];
}
