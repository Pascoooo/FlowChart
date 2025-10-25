// ============================================================================
// 🗄️ DEBUG REPOSITORY - GESTIONE SESSIONE (Business Logic)
// ============================================================================
//
// RESPONSABILITÀ:
// ✅ Creare/gestire sessione debug
// ✅ Eseguire step (delega a ExecutionEngine)
// ✅ Gestire variabili sessione
// ✅ Gestire history (undo)
// ❌ NON emette stati UI
// ❌ NON conosce BLoC
//
// ============================================================================

import 'dart:async';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../debug_repository.dart';
import 'execution_engine.dart';
import 'expression_parser.dart';

class DebugRepoImpl implements DebugRepo {
  DebugSession? _session;
  final List<DebugSnapshot> _history = [];
  final Map<String, Flowchart> _flowcharts;
  final StreamController<Map<String, dynamic>> _varsStream =
  StreamController<Map<String, dynamic>>.broadcast();

  // 🆕 Stato interno: se l'ultimo step ha richiesto input utente
  bool _awaitingInput = false;

  DebugRepoImpl({required Map<String, Flowchart> projectFlowcharts})
      : _flowcharts = projectFlowcharts;

  // ==========================================================================
  // 🚀 SESSIONE
  // ==========================================================================

  @override
  Future<DebugSession> createSession({
    required Flowchart flowchart,
    required List<String> debugPath,
  }) async {
    _session = DebugSession(
      sessionId: const Uuid().v4(),
      flowchartId: flowchart.flowchartId,
      variables: {},
      debugPath: debugPath,
      currentIndex: -1,
      callStack: CallStack.empty(),
      startedAt: DateTime.now(),
    );

    _awaitingInput = false; // reset

    _history.clear();
    _saveSnapshot();
    _varsStream.add(_session!.variables);

    debugPrint('✅ Sessione creata: ${debugPath.length} nodi, indice a -1');
    return _session!;
  }


  // ==========================================================================
  // ⚡ ESECUZIONE STEP (Il Cuore!) - MODIFICATO PER AUTO-ESECUZIONE
  // ==========================================================================

  @override
  Future<ExecutionResult> executeNextStep() async {
    if (_session == null) {
      return ExecutionResult.error('❌ Nessuna sessione');
    }

    // Caso speciale: eravamo in attesa input sul nodo corrente
    if (_awaitingInput) {
      final s = _session!;
      final idx = s.currentIndex;
      if (idx < 0 || idx >= s.debugPath.length) {
        return ExecutionResult.error('Indice non valido in attesa input');
      }

      final flowchart = _getCurrentFlowchart();
      final nodeId = s.debugPath[idx];
      final node = flowchart?.nodes.firstWhere(
            (n) => n.id == nodeId,
        orElse: () => throw StateError('❌ Nodo $nodeId non trovato'),
      );

      if (node == null || flowchart == null) {
        return ExecutionResult.error('❌ Nodo o flowchart non trovato');
      }

      debugPrint('🎯 Rieseguo nodo in attesa input (index $idx): ${node.kind.name}');

      final result = await ExecutionEngine.executeNode(
        node: node,
        variables: s.variables,
        allVariables: flowchart.variables,
      );

      if (!result.success) {
        debugPrint('❌ Errore: ${result.errorMessage}');
        _saveSnapshot();
        return result;
      }

      // Applica eventuali aggiornamenti
      if (result.updatedVariables.isNotEmpty) {
        final allowed = flowchart.variables.map((v) => v.name).toSet();
        final filtered = <String, dynamic>{};
        result.updatedVariables.forEach((k, v) {
          if (allowed.contains(k)) {
            filtered[k] = v;
          } else {
            debugPrint('⚠️ Ignoro update variabile non dichiarata: $k');
          }
        });
        if (filtered.isNotEmpty) {
          final newVars = Map<String, dynamic>.from(s.variables)
            ..addAll(filtered);
          _session = s.copyWith(variables: newVars);
          _varsStream.add(newVars);
          debugPrint('📝 Variabili aggiornate: $filtered');
        }
      }

      // Aggiorna stato attesa input
      _awaitingInput = result.requiresUserInput;

      _saveSnapshot();

      // 🔴 MODIFICA CRUCIALE:
      // Se l'input è stato soddisfatto (_awaitingInput è ora false),
      // NON ritornare, ma prosegui (fall-through) all'avanzamento dello step.
      if (_awaitingInput) {
        // Se richiede ANCORA input (es. validazione fallita), allora fermati e ritorna.
        debugPrint('⏸️ Input ancora richiesto, resto sul nodo.');
        return result;
      }

      debugPrint('✅ Input soddisfatto. Procedo con l\'avanzamento...');
      // Se _awaitingInput è diventato false, l'esecuzione prosegue al blocco "AVANZA PRIMA, POI ESEGUI"
    }

    // ✅ NUOVA LOGICA: AVANZA PRIMA, POI ESEGUI

    // 1️⃣ AVANZA al prossimo indice
    final newIndex = _session!.currentIndex + 1;
    _session = _session!.copyWith(currentIndex: newIndex);
    debugPrint('➡️ Avanzato a index $newIndex');

    // 2️⃣ Check fine percorso
    if (newIndex >= _session!.debugPath.length) {
      _saveSnapshot();
      return ExecutionResult.endOfPath(message: '✅ Fine percorso');
    }

    // 3️⃣ Ottieni nodo al NUOVO indice
    final nodeId = _session!.debugPath[newIndex];
    final flowchart = _getCurrentFlowchart();
    final node = flowchart?.nodes.firstWhere(
          (n) => n.id == nodeId,
      orElse: () => throw StateError('❌ Nodo $nodeId non trovato'),
    );

    if (node == null || flowchart == null) {
      return ExecutionResult.error('❌ Nodo o flowchart non trovato');
    }

    debugPrint('🎯 Eseguendo Step ${newIndex + 1}/${_session!.debugPath.length}: ${node.kind.name}');

    // 4️⃣ ESEGUI il nodo corrente
    final result = await ExecutionEngine.executeNode(
      node: node,
      variables: _session!.variables,
      allVariables: flowchart.variables,
    );

    // 🟠 SOTTOPROGRAMMI: STEP INTO
    if (result.success && result.isSubprogramCall) {
      final targetName = result.subprogramName ?? '';
      final callee = _lookupFlowchartByNameOrId(targetName);
      if (callee == null) {
        debugPrint('❌ Sottoprogramma "$targetName" non trovato');
        // Ripristina indice precedente per evitare blocchi
        _session = _session!.copyWith(currentIndex: newIndex - 1);
        _saveSnapshot();
        return ExecutionResult.error('Sottoprogramma "$targetName" non trovato');
      }

      // Costruisci il percorso del callee a partire dal suo Start
      final calleePath = _buildPathFromStart(callee);
      if (calleePath.isEmpty) {
        // Nessun percorso valido
        _session = _session!.copyWith(currentIndex: newIndex - 1);
        _saveSnapshot();
        return ExecutionResult.error('Percorso del sottoprogramma "$targetName" non valido');
      }

      // Prepara frame di chiamata
      final callerFlowchart = flowchart;
      final callerPathSnapshot = List<String>.from(_session!.debugPath);
      final callerNodeId = node.id;
      final frame = CallStackFrame(
        flowchartId: callee.flowchartId,
        flowchartName: callee.name,
        callerNodeId: callerNodeId,
        parameters: const {},
        returnType: callee.signature.returnType,
        debugPath: callerPathSnapshot,
        callerFlowchart: callerFlowchart,
      );

      // Aggiorna sessione: push frame, switch path al callee e reset indice
      _session = _session!.copyWith(
        callStack: _session!.callStack.push(frame),
        debugPath: calleePath,
        currentIndex: -1,
      );

      // Passaggio parametri: valuta gli arguments del Process e mappali sui parametri della signature del callee
      if (node is ProcessNode) {
        final evaluated = <dynamic>[];
        for (final argExpr in node.arguments) {
          final eval = ExpressionParser.evaluate(argExpr, _session!.variables);
          if (!eval.isValid) {
            debugPrint('⚠️ Argomento non valido "$argExpr": ${eval.errorMessage}');
            continue;
          }
          evaluated.add(eval.value);
        }
        final params = callee.signature.parameters;
        final toAssign = <String, dynamic>{};
        for (int i = 0; i < params.length && i < evaluated.length; i++) {
          final name = params[i].name;
          toAssign[name] = evaluated[i];
        }
        if (toAssign.isNotEmpty) {
          // Aggiorna le variabili in base al callee (ora _getCurrentFlowchart() restituisce il callee)
          await updateVariables(toAssign);
        }
      }

      _saveSnapshot();
      // Ritorna un messaggio informativo, l'UI aggiornerà il flowchart corrente dal callStack
      return ExecutionResult.success(message: '⬇️ Entra in ${callee.name}');
    }

    if (!result.success) {
      debugPrint('❌ Errore: ${result.errorMessage}');
      // Su errore BLOCCANTE, non permettere di avanzare: ripristina indice precedente
      if (result.isBlockingError) {
        _session = _session!.copyWith(currentIndex: newIndex - 1);
        debugPrint('⛔ Errore bloccante: ritorno a index ${_session!.currentIndex}');
      } else {
        // 🆕 Errore NON bloccante: resta sul nodo corrente e segnala attesa di retry
        _awaitingInput = true;
        debugPrint('⚠️ Errore non bloccante: rimango su index $newIndex in attesa di retry');
      }
      _saveSnapshot();
      return result;
    }

    // 5️⃣ AGGIORNA variabili
    if (result.updatedVariables.isNotEmpty) {
      final allowed = flowchart.variables.map((v) => v.name).toSet();
      final filtered = <String, dynamic>{};
      result.updatedVariables.forEach((k, v) {
        if (allowed.contains(k)) {
          filtered[k] = v;
        } else {
          debugPrint('⚠️ Ignoro update variabile non dichiarata: $k');
        }
      });

      if (filtered.isNotEmpty) {
        final newVars = Map<String, dynamic>.from(_session!.variables)
          ..addAll(filtered);
        _session = _session!.copyWith(variables: newVars);
        _varsStream.add(newVars);
        debugPrint('📝 Variabili aggiornate: $filtered');
      }
    }

    // 6️⃣ GESTIONE STATI SPECIALI (Input, Fine, Decisioni, Return)
    _awaitingInput = result.requiresUserInput;

    if (result.requiresUserInput) {
      // Non salviamo uno snapshot qui: evitiamo di registrare lo stato "null" iniziale
      // dell'Input. Lo snapshot verrà creato solo dopo che l'input è stato
      // completato (nel ramo _awaitingInput), garantendo che il Previous non
      // ripristini valori null involontariamente.
      debugPrint('⏸️ In attesa input utente: ${result.userInputPrompt ?? ''}');
      return result;
    }

    if (result.hasReturnValue) {
      // Ritorno da sottoprogramma: pop dallo stack, ripristina path e assegnazione a resultTarget
      if (_session!.callStack.isEmpty) {
        // Return nel main: ignora pop, ma registra il messaggio
        _saveSnapshot();
        return result;
      }

      final top = _session!.callStack.current!;
      // Ripristina il percorso del chiamante
      final callerPath = List<String>.from(top.debugPath);
      final callerFlow = top.callerFlowchart;

      // Trova indice del nodo chiamante per riprendere dal successivo
      final callIndex = callerPath.indexOf(top.callerNodeId ?? '');
      final restoreIndex = callIndex >= 0 ? callIndex : (callerPath.length - 1);

      // Pop stack e ripristina path
      _session = _session!.copyWith(
        callStack: _session!.callStack.pop(),
        debugPath: callerPath,
        currentIndex: restoreIndex,
      );

      // Assegna valore di ritorno al resultTarget del ProcessNode chiamante
      try {
        final callerNode = callerFlow.nodes.firstWhere((n) => n.id == (top.callerNodeId ?? '')) as ProcessNode;
        final targetName = callerNode.resultTarget;
        if (targetName != null && targetName.isNotEmpty) {
          await updateVariables({targetName: result.returnValue});
        }
      } catch (_) {
        // Nessun target o nodo non trovato: ignora
      }

      _saveSnapshot();
      return ExecutionResult.success(message: '⬆️ Return ${result.returnValue ?? ""}');
    }

    if (result.isEndOfPath) {
      _saveSnapshot();
      debugPrint('🏁 Fine percorso raggiunta dal nodo End');
      return result;
    }

    // 🧠 NUOVO: su Decision/While/Do-While aggiorna il percorso in base al ramo scelto
    if (node.kind == FlowNodeKind.decision || node.kind == FlowNodeKind.whileLoop || node.kind == FlowNodeKind.doWhileLoop) {
      final branch = result.decisionBranch;
      if (branch == null) {
        _saveSnapshot();
        return result;
      }

      final nextId = _chooseNextNodeId(flowchart, node.id, node.kind, branch);
      if (nextId == null) {
        _saveSnapshot();
        return ExecutionResult.error('Nessun edge valido per ramo "$branch" dal nodo ${node.kind.name}');
      }

      final remainder = _buildDefaultPath(flowchart, startNodeId: nextId);
      final head = _session!.debugPath.sublist(0, newIndex + 1);
      _session = _session!.copyWith(debugPath: [...head, ...remainder]);
      debugPrint('🧭 Ricalcolato percorso da decisione (${branch}): ${remainder.length} nodi');
    }

    // 7️⃣ Salva lo stato DOPO l'esecuzione
    _saveSnapshot();

    if (result.outputMessage != null) {
      debugPrint('✅ ${result.outputMessage}');
    }

    return result;
  }

  // Helper: costruisci path dal punto di ingresso del flowchart (Start per main, FunctionHeader per funzioni)
  List<String> _buildPathFromStart(Flowchart flowchart) {
    // 1) Prova con Start (main)
    try {
      final start = flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.start);
      return _buildDefaultPath(flowchart, startNodeId: start.id);
    } catch (_) {
      // continua
    }

    // 2) Prova con FunctionHeader (funzioni)
    try {
      final header = flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.functionHeader);
      return _buildDefaultPath(flowchart, startNodeId: header.id);
    } catch (_) {
      // continua
    }

    // 3) Fallback: primo nodo senza archi in ingresso (entry naturale)
    final nodeIds = flowchart.nodes.map((n) => n.id).toSet();
    final withIncoming = flowchart.edges.map((e) => e.to).toSet();
    final candidates = nodeIds.difference(withIncoming);
    if (candidates.isNotEmpty) {
      final entryId = candidates.first;
      return _buildDefaultPath(flowchart, startNodeId: entryId);
    }

    // Nessun entry trovato
    return <String>[];
  }

  // Helper: risolvi flowchart per nome o id
  Flowchart? _lookupFlowchartByNameOrId(String nameOrId) {
    if (_flowcharts.containsKey(nameOrId)) return _flowcharts[nameOrId];
    try {
      return _flowcharts.values.firstWhere((f) => f.name == nameOrId || f.flowchartId == nameOrId);
    } catch (_) {
      return null;
    }
  }

  List<String> _buildDefaultPath(Flowchart flowchart, {required String startNodeId}) {
    final path = <String>[];
    final visited = <String>{};

    String? currentId = startNodeId;
    while (currentId != null && currentId.isNotEmpty) {
      if (visited.contains(currentId)) break; // previeni loop
      path.add(currentId);
      visited.add(currentId);

      final currentNode = flowchart.nodes.firstWhere(
            (n) => n.id == currentId,
        orElse: () => const StartNode(id: '', x: 0, y: 0, width: 0, height: 0, text: ''),
      );
      if (currentNode.id.isEmpty) break;
      if (currentNode.kind == FlowNodeKind.end) break;

      final outgoing = flowchart.edges.where((e) => e.from == currentId).toList();
      if (outgoing.isEmpty) break;

      // Priorità: edge senza porta, poi primo edge che non sia 'loop'
      FlowchartEdge? next = outgoing.firstWhere(
            (e) => e.port == null || e.port!.isEmpty,
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );
      if (next.from.isEmpty) {
        next = outgoing.firstWhere(
              (e) => e.port != 'loop',
          orElse: () => outgoing.first,
        );
      }
      currentId = next.to;
    }

    return path;
  }

  // Helper: risolve il prossimo nodo in base al ramo scelto
  String? _chooseNextNodeId(Flowchart flowchart, String fromNodeId, FlowNodeKind kind, String branch) {
    final outgoing = flowchart.edges.where((e) => e.from == fromNodeId).toList();
    if (outgoing.isEmpty) return null;

    if (kind == FlowNodeKind.doWhileLoop) {
      // Nel do-while il branch 'loop' corrisponde alla porta 'true' (ripetere), altrimenti 'false'
      final desiredPort = branch == 'loop' ? 'true' : 'false';
      final edge = outgoing.firstWhere(
            (e) => (e.port ?? '') == desiredPort || (desiredPort.isEmpty && (e.port == null || e.port!.isEmpty)),
        orElse: () => const FlowchartEdge(from: '', to: ''),
      );
      return edge.from.isEmpty ? null : edge.to;
    }

    // Decision/While: branch 'true'/'false'
    final edge = outgoing.firstWhere(
          (e) => (e.port ?? '') == branch,
      orElse: () => const FlowchartEdge(from: '', to: ''),
    );
    return edge.from.isEmpty ? null : edge.to;
  }

  // ==========================================================================
  // ⏮️ STEP INDIETRO (Undo)
  // ==========================================================================

  @override
  Future<void> previousStep() async {
    if (!canGoBack()) throw StateError('❌ Non puoi tornare indietro');

    // Mantieni le variabili correnti per evitare reset indesiderati (es. Assignment runtime)
    final currentVars = Map<String, dynamic>.from(_session?.variables ?? {});

    _history.removeLast(); // Rimuovi stato corrente
    final snapshot = _history.last; // Ripristina precedente

    // Ripristina indice, path e stack, ma preserva le variabili correnti
    _session = snapshot.session.copyWith(variables: currentVars);
    _varsStream.add(_session!.variables);

    debugPrint('⬅️ Tornato a index ${_session!.currentIndex} (variabili preservate)');
  }

  @override
  bool canGoBack() => _history.length > 1;

  // ==========================================================================
  // 🔍 QUERY
  // ==========================================================================

  @override
  DebugSession? getCurrentSession() => _session;

  @override
  Map<String, dynamic> getVariables() {
    return Map.unmodifiable(_session?.variables ?? {});
  }

  @override
  Stream<Map<String, dynamic>> watchVariables() => _varsStream.stream;

  @override
  List<DebugSnapshot> getHistory() => List.unmodifiable(_history);

  // ==========================================================================
  // 🎲 CONDIZIONI
  // ==========================================================================

  @override
  Future<bool> evaluateCondition({
    required List<ConditionClause> clauses,
    required String logicalJoin,
  }) async {
    if (_session == null) throw StateError('❌ Nessuna sessione');

    return ExecutionEngine.evaluateCondition(
      clauses: clauses,
      logicalJoin: logicalJoin,
      variables: _session!.variables,
    );
  }

  // ==========================================================================
  // 🛠️ UTILITIES
  // ==========================================================================

  @override
  Future<void> updateVariables(Map<String, dynamic> variables) async {
    if (_session == null) return;

    // Consenti aggiornamenti solo per variabili dichiarate nel flowchart corrente
    final flowchart = _getCurrentFlowchart();
    if (flowchart == null) return;

    final declarations = {for (final v in flowchart.variables) v.name: v};
    final allowed = declarations.keys.toSet();
    final filtered = <String, dynamic>{};
    for (final entry in variables.entries) {
      final k = entry.key;
      final v = entry.value;
      if (!allowed.contains(k)) {
        debugPrint('⚠️ updateVariables ignorata per variabile non dichiarata: $k');
        continue;
      }
      final decl = declarations[k]!;
      if (!_isRuntimeValueCompatibleWithDeclaration(v, decl)) {
        debugPrint('⚠️ Tipo incompatibile per "$k": ${v.runtimeType} → ${decl.dataType}');
        // Salta aggiornamento non compatibile
        continue;
      }
      filtered[k] = v;
    }

    if (filtered.isEmpty) return;

    final newVars = Map<String, dynamic>.from(_session!.variables)
      ..addAll(filtered);
    _session = _session!.copyWith(variables: newVars);
    _varsStream.add(newVars);
  }

  bool _isRuntimeValueCompatibleWithDeclaration(dynamic value, VariableDeclaration decl) {
    if (value == null) return true; // consenti null (es. dichiarazione input)
    final target = decl.dataType.toLowerCase();
    final intTypes = {'int', 'integer'};
    final doubleTypes = {'double', 'float', 'number'};
    final boolTypes = {'bool', 'boolean'};
    final stringTypes = {'string', 'str', 'text'};

    if (intTypes.contains(target)) return value is int;
    if (doubleTypes.contains(target)) return value is double || value is int; // widening
    if (boolTypes.contains(target)) return value is bool;
    if (stringTypes.contains(target)) return value is String;
    // tipi sconosciuti: accetta conservativamente
    return true;
  }

  @override
  Future<void> updateDebugPath(List<String> newPath, {int? newIndex}) async {
    if (_session == null) return;
    _session = _session!.copyWith(
      debugPath: newPath,
      currentIndex: newIndex ?? _session!.currentIndex,
    );
  }

  @override
  Future<void> endSession() async {
    _session = null;
    _awaitingInput = false;
    _history.clear();
    _varsStream.add({});
    debugPrint('🛑 Sessione terminata');
  }

  @override
  void saveSnapshot() => _saveSnapshot();

  void _saveSnapshot() {
    if (_session == null) return;
    _history.add(DebugSnapshot(
      session: _session!,
      timestamp: DateTime.now(),
    ));
  }

  Flowchart? _getCurrentFlowchart() {
    if (_session == null) return null;

    // Se in sottoprogramma, risolvi per ID o nome del frame corrente
    if (_session!.callStack.isNotEmpty) {
      final frame = _session!.callStack.frames.last;
      final byId = _lookupFlowchartByNameOrId(frame.flowchartId);
      if (byId != null) return byId;
      final byName = _lookupFlowchartByNameOrId(frame.flowchartName);
      if (byName != null) return byName;
      // Nessuna corrispondenza esplicita: evita fallback per non cambiare contesto inaspettatamente
      return null;
    }

    // Altrimenti usa il flowchart principale della sessione (per ID)
    final mainById = _lookupFlowchartByNameOrId(_session!.flowchartId);
    if (mainById != null) return mainById;

    // Se non trovato, non forzare un fallback arbitrario: meglio segnalare null e gestire a monte
    return null;
  }

  @override
  Future<void> syncProjectFlowcharts(Map<String, Flowchart> projectFlowcharts) async {
    // Sostituisce il contenuto della mappa mantenendo il riferimento
    _flowcharts
      ..clear()
      ..addAll(projectFlowcharts);
    debugPrint('🔄 Flowchart sincronizzati: ${_flowcharts.length} file');
  }

  void dispose() {
    _varsStream.close();
  }
}