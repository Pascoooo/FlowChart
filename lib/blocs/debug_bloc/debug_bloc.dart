/// Debug BLoC gestisce il ciclo di vita del debugging dei flowchart.
/// Coordina l'esecuzione step-by-step, navigazione avanti/indietro,
/// gestione input utente (decisioni/assignment), step into/out sottoprogrammi.
/// Delega tutta la logica di esecuzione nodi al DebugRepository e traduce risultati in stati UI.
/// Mantiene cache del contesto per resilienza e risolve il flowchart corretto in caso di chiamate.
import 'package:bloc/bloc.dart';
import 'package:debug_repository/debug_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/foundation.dart';
import '../flowchart_bloc/flowchart_state.dart';
import 'debug_event.dart';
import 'debug_state.dart';

class DebugBloc extends Bloc<DebugEvent, DebugState> {
  final DebugRepo debugRepository;

  // 🆕 Cache del contesto corrente per resilienza UI
  Flowchart? _lastFlowchart;
  Map<String, Flowchart> _lastProjectFlowcharts = const {};

  /// Inizializza il BLoC con DebugRepository e registra tutti gli event handler.
  /// Gestisce start/stop, step avanti/indietro, input utente, step into/out e aggiornamento variabili.
  DebugBloc({required this.debugRepository}) : super(const DebugInitial()) {
    on<DebugStart>(_onStart);
    on<DebugNext>(_onNext);
    on<DebugPrevious>(_onPrevious);
    on<DebugStop>(_onStop);
    on<DebugResetFirstStep>(_onResetFirstStep);
    on<DebugEvaluateDecision>(_onEvaluateDecision);
    on<DebugUpdateVariables>(_onUpdateVariables);
    on<DebugStepInto>(_onStepInto);
    on<DebugStepOut>(_onStepOut);
  }

  /// Risolve il flowchart corrente in base al call stack della sessione.
  /// Se siamo in un sottoprogramma, cerca nel call stack; altrimenti usa il flowchart principale.
  /// Implementa fallback multipli per resilienza: ID, nome, primo match.
  Flowchart _resolveCurrentFlowchart(Flowchart fallback, Map<String, Flowchart> projectFlowcharts, DebugSession session) {
    // Se siamo dentro un sottoprogramma, usa il flowchart dal top del call stack
    if (session.callStack.isNotEmpty) {
      final top = session.callStack.current!;
      // 1) prova per ID
      try {
        final byId = projectFlowcharts.values.firstWhere((f) => f.flowchartId == top.flowchartId);
        return byId;
      } catch (_) {}
      // 2) poi per nome
      final byName = projectFlowcharts[top.flowchartName];
      if (byName != null) return byName;
      // 3) fallback: prima occorrenza per nome/id
      try {
        return projectFlowcharts.values.firstWhere((f) => f.name == top.flowchartName || f.flowchartId == top.flowchartId);
      } catch (_) {
        return fallback;
      }
    }

    // Stack vuoto: siamo nel chiamante (main o superiore)
    // 1) Prova a risolvere per flowchartId della sessione
    try {
      final mainById = projectFlowcharts.values.firstWhere((f) => f.flowchartId == session.flowchartId);
      return mainById;
    } catch (_) {}

    // 2) Se possibile, risolvi in base al nodo corrente nel debugPath
    if (session.currentIndex >= 0 && session.currentIndex < session.debugPath.length) {
      final nodeId = session.debugPath[session.currentIndex];
      try {
        final containing = projectFlowcharts.values.firstWhere((f) => f.nodes.any((n) => n.id == nodeId));
        return containing;
      } catch (_) {}
    }

    // 3) Fallback ultimo stato noto
    return fallback;
  }

  /// Valida la struttura del flowchart prima di avviare il debug.
  /// Verifica do-while con corpo non definito, while con corpo ma senza chiusura, nodo Fine nel corpo while.
  /// Blocca debug se rileva incongruenze strutturali.
  bool _validateStructureForDebug(Flowchart flowchart) {
    final s = FlowchartLoaded(flowchart: flowchart);

    // 1) Post-condizionale (do-while): è obbligatoria la selezione del nodo di inizio corpo
    final unresolved = s.unresolvedDoWhileIds();
    for (final dwId in unresolved) {
      final hasCandidates = s.hasEligibleDoWhileBodyCandidates(dwId);
      if (hasCandidates) {
        debugPrint('⛔ Debug bloccato: do-while $dwId senza corpo. Seleziona un nodo valido come inizio corpo.');
      } else {
        debugPrint('⛔ Debug bloccato: do-while $dwId senza corpo e senza candidati validi. Aggiungi almeno un blocco prima del ciclo.');
      }
      return false; // blocca al primo irregolare
    }

    // 2) While (pre-condizionale): se c'è almeno un blocco nel corpo, deve esistere la chiusura del ciclo (edge "loop")
    for (final n in s.flowchart.nodes) {
      if (n.kind != FlowNodeKind.whileLoop) continue;
      final body = s.whileBodyNodes(n.id);
      if (body.isNotEmpty && !s.whileHasLoopClosure(n.id)) {
        debugPrint('⛔ Debug bloccato: nel while ${n.id} c\'è almeno un blocco ma manca la chiusura del ciclo (fine ciclo).');
        return false;
      }

      // 3) Vietato avere un nodo Fine nel corpo del while
      if (body.isNotEmpty) {
        final endIds = s.flowchart.nodes.where((x) => x.kind == FlowNodeKind.end).map((x) => x.id).toSet();
        final hasDirectEnd = s.flowchart.edges.any((e) => body.contains(e.from) && endIds.contains(e.to));
        if (hasDirectEnd) {
          debugPrint('⛔ Debug bloccato: trovato un collegamento a "Fine" dentro il corpo del while ${n.id}. Usa la chiusura del ciclo.');
          return false;
        }
      }
    }

    return true;
  }

  /// Avvia una nuova sessione di debug.
  /// Valida struttura, sincronizza flowchart progetto, costruisce debug path ed esegue automaticamente il primo step.
  Future<void> _onStart(DebugStart event, Emitter<DebugState> emit) async {
    try {
      debugPrint('🎬 Debug Start');

      // 🔍 Validazione struttura prima di avviare qualunque sessione
      if (!_validateStructureForDebug(event.flowchart)) {
        emit(const DebugError('Struttura non valida per il debug', isBlocking: true));
        return;
      }

      // 🔄 Sincronizza i flowchart del progetto nel repository prima di creare la sessione
      await debugRepository.syncProjectFlowcharts(event.projectFlowcharts);

      final debugPath = _buildDebugPath(event.flowchart);
      if (debugPath.isEmpty) {
        emit(const DebugError('Impossibile costruire il percorso di debug'));
        return;
      }

      debugPrint('🔍 Debug path costruito: ${debugPath.length} nodi');
      debugPrint('📍 Path: ${debugPath.join(' -> ')}');

      await debugRepository.createSession(
        flowchart: event.flowchart,
        debugPath: debugPath,
      );

      // Cache contesto per fallback
      _lastFlowchart = event.flowchart;
      _lastProjectFlowcharts = event.projectFlowcharts;

      // ✅ NUOVA LOGICA: Esegui il primo step (StartNode) automaticamente, passando il contesto
      debugPrint('🚀 Esecuzione primo step...');
      add(DebugNext(
        isAutoStart: true,
        initialFlowchart: event.flowchart,
        initialProjectFlowcharts: event.projectFlowcharts,
      ));

    } catch (e) {
      debugPrint('❌ Errore avvio debug: $e');
      emit(DebugError('Errore avvio: $e'));
    }
  }

  /// Costruisce il debug path completo seguendo gli archi del flowchart.
  /// Parte dal nodo Start e segue gli edge di uscita predefiniti fino al nodo End.
  /// Previene loop infiniti con set visited e gestisce priorità edge (null > non-loop).
  List<String> _buildDebugPath(Flowchart flowchart) {
    final path = <String>[];
    final visited = <String>{};

    // Trova il nodo Start
    final startNode = flowchart.nodes.firstWhere(
          (n) => n.kind == FlowNodeKind.start,
      orElse: () => throw Exception('Nodo Start non trovato'),
    );

    String? currentId = startNode.id;

    while (currentId != null && currentId.isNotEmpty) {
      // Previeni loop infiniti
      if (visited.contains(currentId)) {
        debugPrint('⚠️ Loop rilevato al nodo: $currentId');
        break;
      }

      path.add(currentId);
      visited.add(currentId);

      // Trova il nodo corrente
      final currentNode = flowchart.nodes.firstWhere(
            (n) => n.id == currentId,
        orElse: () => throw Exception('Nodo non trovato: $currentId'),
      );

      // Se è un nodo End, termina
      if (currentNode.kind == FlowNodeKind.end) {
        break;
      }

      // Trova l'edge di uscita "default" (senza porta o con porta principale)
      final outgoing = flowchart.edges.where((e) => e.from == currentId).toList();

      if (outgoing.isEmpty) {
        debugPrint('⚠️ Nessun edge di uscita dal nodo: $currentId');
        break;
      }

      // Priorità:
      // 1. Edge senza porta (null o vuoto)
      // 2. Edge con porta != 'loop' e != 'false' (per nodi condizionali prendi il default/true)
      FlowchartEdge? next = outgoing.firstWhere(
            (e) => e.port == null || e.port!.isEmpty,
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );

      // Se non trovato, cerca il primo edge che non sia 'loop'
      if (next.from.isEmpty && outgoing.isNotEmpty) {
        next = outgoing.firstWhere(
              (e) => e.port != 'loop',
          orElse: () => outgoing.first,
        );
      }

      if (next.from.isEmpty) {
        debugPrint('⚠️ Nessun edge valido trovato dal nodo: $currentId');
        break;
      }

      currentId = next.to;
    }

    return path;
  }

  /// Resetta il flag isFirstStep dopo il rendering iniziale con zoom.
  /// Previene zoom ripetuto su UI refresh.
  Future<void> _onResetFirstStep(DebugResetFirstStep event, Emitter<DebugState> emit) async {
    if (state is! DebugInProgress) return;
    final currentState = state as DebugInProgress;

    if (currentState.isFirstStep) {
      debugPrint('✅ Reset flag isFirstStep');
      emit(currentState.copyWith(isFirstStep: false));
    }
  }

  /// Esegue il prossimo step del debug.
  /// Delega esecuzione al repository, gestisce risultati (successo/errore/input richiesto/fine percorso).
  /// Previene re-entrancy con flag isProcessing. Auto-esegue primo step se isAutoStart.
  Future<void> _onNext(DebugNext event, Emitter<DebugState> emit) async {
    // Evita re-entrancy: se stiamo già elaborando, ignora
    if (state is DebugInProgress) {
      final s = state as DebugInProgress;
      if (s.isProcessing) return;
    }

    // Esegui comunque se esiste una sessione; evita early-return che causa "skip" visivo
    final activeSession = debugRepository.getCurrentSession();
    if (activeSession == null) {
      emit(const DebugError('Nessuna sessione di debug attiva'));
      return;
    }

    try {
      // Ottieni i dati necessari dallo stato corrente o dall'evento di start
      Flowchart flowchart;
      Map<String, Flowchart> projectFlowcharts;

      if (state is DebugInProgress) {
        final s = state as DebugInProgress;
        flowchart = s.currentFlowchart;
        projectFlowcharts = s.projectFlowcharts;
      } else if (state is DebugAwaitingInput) {
        final s = state as DebugAwaitingInput;
        flowchart = s.currentFlowchart;
        projectFlowcharts = s.projectFlowcharts;
      } else {
        // Fallback robusto quando la UI è tornata a DebugInitial ma la sessione esiste
        projectFlowcharts = event.initialProjectFlowcharts ?? _lastProjectFlowcharts;
        flowchart = event.initialFlowchart ?? _lastFlowchart ??
            projectFlowcharts.values.firstWhere(
                  (f) => f.flowchartId == activeSession.flowchartId,
              orElse: () => projectFlowcharts.values.first,
            );
      }

      debugPrint('➡️ Next');

      // 🔒 Imposta stato in elaborazione per disabilitare Next
      await _emitRunningState(
        emit,
        flowchart,
        projectFlowcharts,
        isFirst: false,
        setProcessing: true,
      );

      // 1️⃣ ESEGUI step (il repository ora fa "avanza e esegui")
      final result = await debugRepository.executeNextStep();

      // 2️⃣ GESTISCI risultato
      if (!result.success) {
        if (result.isBlockingError) {
          emit(DebugError(result.errorMessage ?? 'Errore', isBlocking: true));
          // Rilascia il lock
          if (state is DebugInProgress) {
            final s = state as DebugInProgress;
            emit(s.copyWith(isProcessing: false));
          }
        } else {
          // 🆕 Errore NON bloccante: resta in esecuzione e mostra l'errore in console
          final session = debugRepository.getCurrentSession();
          if (session == null) {
            emit(const DebugError('Nessuna sessione di debug attiva'));
            return;
          }
          emit(DebugInProgress(
            session: session,
            currentFlowchart: flowchart,
            projectFlowcharts: projectFlowcharts,
            isFirstStep: false,
            lastMessage: result.errorMessage,
            lastUpdatedVariables: null,
            isProcessing: false,
            lastMessageIsError: true,
          ));
        }
        return;
      }

      // Se è fine percorso
      if (result.isEndOfPath) {
        debugPrint('✅ Completato');
        emit(const DebugCompleted(message: 'Esecuzione completata'));
        return;
      }

      final session = debugRepository.getCurrentSession()!;

      // Se richiede input utente: emetti DebugAwaitingInput (Next deve restare disabilitato fino a input)
      if (result.requiresUserInput) {
        debugPrint('⏸️ In attesa input: ${result.userInputPrompt}');
        final effectiveFlowchart = _resolveCurrentFlowchart(flowchart, projectFlowcharts, session);
        final currentNode = effectiveFlowchart.nodes.firstWhere((n) => n.id == session.debugPath[session.currentIndex]);
        final Set<String> targets;
        if (currentNode is AssignmentNode) {
          targets = (currentNode)
              .assignments
              .where((a) => a.expression.trim().isEmpty)
              .map((a) => a.target)
              .toSet();
        } else if (currentNode is InputNode) {
          targets = (currentNode)
              .assignments
              .where((a) => a.expression.trim().isEmpty)
              .map((a) => a.target)
              .toSet();
        } else {
          targets = <String>{};
        }

        emit(DebugAwaitingInput(
          session: session,
          currentFlowchart: flowchart,
          promptMessage: result.userInputPrompt ?? 'Inserisci i valori richiesti',
          projectFlowcharts: projectFlowcharts,
          targets: targets,
        ));
        return;
      }

      // 3️⃣ EMETTI nuovo stato running con l'ultimo esito da mostrare in console e rilascia il lock
      await _emitRunningState(
        emit,
        flowchart,
        projectFlowcharts,
        isFirst: event.isAutoStart, // Segna il primo step per lo zoom
        lastMessage: result.outputMessage,
        lastUpdatedVariables: result.updatedVariables.isNotEmpty ? result.updatedVariables : null,
        setProcessing: false,
      );

      // 4️⃣ MOSTRA output se presente (log dev)
      if (result.outputMessage != null && result.outputMessage!.isNotEmpty) {
        debugPrint('📣 ${result.outputMessage}');
      }
    } catch (e) {
      debugPrint('❌ Errore in _onNext: $e');
      emit(DebugError('Errore: $e'));
    }
  }

  /// Torna allo step precedente (undo).
  /// Previene navigazione indietro se non possibile e gestisce lock isProcessing.
  Future<void> _onPrevious(DebugPrevious event, Emitter<DebugState> emit) async {
    if (state is! DebugInProgress) return;
    final s = state as DebugInProgress;
    if (s.isProcessing) return; // 🔒 evita azioni mentre elabori

    try {
      if (!debugRepository.canGoBack()) {
        debugPrint('⚠️ Non puoi tornare indietro');
        return;
      }

      // Imposta lock
      emit(s.copyWith(isProcessing: true));

      debugPrint('⬅️ Previous');
      await debugRepository.previousStep();

      await _emitRunningState(
        emit,
        s.currentFlowchart,
        s.projectFlowcharts,
        setProcessing: false,
      );
    } catch (e) {
      debugPrint('❌ Errore: $e');
      // Rilascia lock in caso di errore
      emit(s.copyWith(isProcessing: false));
    }
  }

  /// Termina la sessione di debug corrente e ritorna allo stato iniziale.
  Future<void> _onStop(DebugStop event, Emitter<DebugState> emit) async {
    try {
      await debugRepository.endSession();
      debugPrint('🛑 Stop');
      emit(const DebugInitial());
    } catch (e) {
      emit(const DebugInitial());
    }
  }

  // ==========================================================================
  // 🎲 EVALUATE DECISION
  // ==========================================================================

  Future<void> _onEvaluateDecision(DebugEvaluateDecision event, Emitter<DebugState> emit) async {
    // Questo evento è gestito dal repository durante executeNextStep
    // Il DebugBloc si limita a delegare
    debugPrint('🎲 Decisione valutata: ${event.result}');
  }

  /// Aggiorna le variabili durante il debug (input utente per assignment/input node).
  /// Delega aggiornamento al repository e ri-emette stato corrente con variabili aggiornate.
  Future<void> _onUpdateVariables(DebugUpdateVariables event, Emitter<DebugState> emit) async {
    try {
      await debugRepository.updateVariables(event.variables);
      final session = debugRepository.getCurrentSession();
      if (session == null) {
        emit(const DebugError('Sessione persa durante aggiornamento variabili'));
        return;
      }

      if (state is DebugAwaitingInput) {
        final s = state as DebugAwaitingInput;
        // Rimaniamo sullo stesso nodo in attesa che l'utente prema Next
        emit(DebugAwaitingInput(
          session: session,
          currentFlowchart: s.currentFlowchart,
          promptMessage: s.promptMessage,
          projectFlowcharts: s.projectFlowcharts,
        ));
      } else if (state is DebugInProgress) {
        final s = state as DebugInProgress;
        // Ri-emetti stato in-progress con variabili aggiornate
        emit(DebugInProgress(
          session: session,
          currentFlowchart: s.currentFlowchart,
          projectFlowcharts: s.projectFlowcharts,
          isFirstStep: s.isFirstStep,
        ));
      }
    } catch (e) {
      emit(DebugError('Errore aggiornando variabili: $e'));
    }
  }

  /// Entra nel sottoprogramma chiamato dal nodo ProcessNode corrente.
  /// Delega gestione call stack al repository e aggiorna stato.
  Future<void> _onStepInto(DebugStepInto event, Emitter<DebugState> emit) async {
    if (state is! DebugInProgress) return;

    try {
      debugPrint('⬇️ Step into: ${event.node.flowchartToCall}');

      // Il repository gestisce l'entrata nel sottoprogramma
      final result = await debugRepository.executeNextStep();

      if (!result.success) {
        emit(DebugError(result.errorMessage ?? 'Errore step into'));
        return;
      }

      final currentState = state as DebugInProgress;
      await _emitRunningState(
        emit,
        currentState.currentFlowchart,
        currentState.projectFlowcharts,
      );
    } catch (e) {
      debugPrint('❌ Errore step into: $e');
      emit(DebugError('Errore step into: $e'));
    }
  }

  /// Ritorna dal sottoprogramma corrente al chiamante con valore di ritorno.
  /// Delega gestione call stack al repository e aggiorna stato.
  Future<void> _onStepOut(DebugStepOut event, Emitter<DebugState> emit) async {
    if (state is! DebugInProgress) return;

    try {
      debugPrint('⬆️ Step out (return: ${event.returnValue})');

      // Il repository gestisce il ritorno dal sottoprogramma
      final result = await debugRepository.executeNextStep();

      if (!result.success) {
        emit(DebugError(result.errorMessage ?? 'Errore step out'));
        return;
      }

      final currentState = state as DebugInProgress;
      await _emitRunningState(
        emit,
        currentState.currentFlowchart,
        currentState.projectFlowcharts,
      );
    } catch (e) {
      debugPrint('❌ Errore step out: $e');
      emit(DebugError('Errore step out: $e'));
    }
  }

  /// Emette stato DebugInProgress pulito con sessione corrente.
  /// Risolve il flowchart effettivo (callee se in sottoprogramma) e gestisce indice negativo o fine percorso.
  Future<void> _emitRunningState(
      Emitter<DebugState> emit,
      Flowchart flowchart,
      Map<String, Flowchart> projectFlowcharts, {
        bool isFirst = false,
        String? lastMessage,
        Map<String, dynamic>? lastUpdatedVariables,
        bool? setProcessing,
      }) async {
    final session = debugRepository.getCurrentSession();
    if (session == null) {
      emit(const DebugError('Sessione persa'));
      return;
    }

    // Determina il flowchart effettivo da mostrare: callee se siamo dentro un sottoprogramma
    final effectiveFlowchart = _resolveCurrentFlowchart(flowchart, projectFlowcharts, session);

    // Se l'indice è -1, significa che siamo prima dell'inizio, emetti lo stato iniziale.
    if (session.currentIndex < 0) {
      emit(DebugInProgress(
        session: session,
        currentFlowchart: effectiveFlowchart,
        projectFlowcharts: projectFlowcharts,
        isFirstStep: true, // Segna come primo step per lo zoom
        lastMessage: lastMessage,
        lastUpdatedVariables: lastUpdatedVariables,
        isProcessing: setProcessing ?? false,
      ));
      return;
    }

    // Verifica fine percorso (doppio controllo di sicurezza)
    if (session.currentIndex >= session.debugPath.length) {
      emit(const DebugCompleted());
      return;
    }

    emit(DebugInProgress(
      session: session,
      currentFlowchart: effectiveFlowchart,
      projectFlowcharts: projectFlowcharts,
      isFirstStep: isFirst,
      lastMessage: lastMessage,
      lastUpdatedVariables: lastUpdatedVariables,
      isProcessing: setProcessing ?? false,
      lastMessageIsError: false,
    ));

    debugPrint('🎯 Stato aggiornato. Nodo corrente: ${session.debugPath[session.currentIndex]} (index ${session.currentIndex})');
  }
}