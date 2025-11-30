/// Debug console widget per l'inserimento degli input durante il debug dei flowchart.
/// Mostra la cronologia e delega la logica al DebugEngine.
/// Presentation-only component that delegates business logic to DebugBloc and DebugEngine.
// ============================================================================
// 🎨 DEBUG CONSOLE - UI COMPONENT (Presentation Only)
// ============================================================================
//
// RESPONSABILITÀ:
// ✅ Mostrare la console di debug
// ✅ Raccogliere input utente
// ✅ Ascoltare stati del DebugBloc
// ❌ NON esegue logica di business
// ❌ NON accede al repository
// ❌ NON gestisce variabili direttamente
//
// ============================================================================

import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../blocs/debug_bloc/debug_bloc.dart';
import '../../../../../blocs/debug_bloc/debug_event.dart';
import '../../../../../blocs/debug_bloc/debug_state.dart';
import 'console_models.dart';
import 'console_entry_widget.dart';
import 'debug_engine.dart'; // ✅ Ora usa la versione pulita

class DebugConsole extends StatefulWidget {
  const DebugConsole({super.key});

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  DebugEngine? _engine;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ConsoleEntry> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _initializeEngine();
    });
  }

  void _initializeEngine() {
    final debugState = context.read<DebugBloc>().state;

    // Consenti inizializzazione sia in DebugInProgress che in DebugAwaitingInput
    if (debugState is! DebugInProgress && debugState is! DebugAwaitingInput) {
      debugPrint('⚠️ Impossibile inizializzare console: non in debug');
      return;
    }

    // Determina il nodo corrente e il flowchart corrente
    final session = (debugState is DebugInProgress)
        ? debugState.session
        : (debugState as DebugAwaitingInput).session;

    // FIX: se l'indice è negativo, attendi il primo Next
    if (session.currentIndex < 0) {
      debugPrint('⏳ Console in attesa: indice corrente = -1 (premi Next)');
      return;
    }

    final flowchart = (debugState is DebugInProgress)
        ? debugState.currentFlowchart
        : (debugState as DebugAwaitingInput).currentFlowchart;

    if (session.currentIndex >= session.debugPath.length) {
      debugPrint('⚠️ Indice fuori range');
      return;
    }

    final nodeId = session.debugPath[session.currentIndex];
    final currentNode = flowchart.nodes.firstWhere(
          (n) => n.id == nodeId,
      orElse: () => throw StateError('Nodo non trovato: $nodeId'),
    );

    // Determina se siamo in un do-while re-entry
    bool isReentry = false;
    if (currentNode is DoWhileNode) {
      isReentry = session.currentIndex > 0;
    }

    // Determina se siamo in un sottoprogramma
    final isInSubprogram = (debugState is DebugInProgress)
        ? debugState.callStack.isNotEmpty
        : false; // opzionale per AwaitingInput

    _engine = DebugEngine(
      currentNode: currentNode,
      onHistoryUpdate: _handleHistoryUpdate,
      onDebugNext: () => context.read<DebugBloc>().add(const DebugNext()),
      onDebugPrev: () => context.read<DebugBloc>().add(const DebugPrevious()),
      onDebugStop: () => context.read<DebugBloc>().add(const DebugStop()),
      onVariablesUpdate: (vars) {
        context.read<DebugBloc>().add(DebugUpdateVariables(vars));
      },
      getVariables: () {
        final s = context.read<DebugBloc>().state;
        if (s is DebugInProgress) return s.session.variables;
        if (s is DebugAwaitingInput) return s.session.variables;
        return <String, dynamic>{};
      },
      // 🔴 MODIFICATO: Controlla InputNode invece di AssignmentNode
      allowedAssignmentTargets: currentNode is InputNode
          ? (currentNode).assignments.map((a) => a.target).toSet()
          : null,
      isDoWhileReentry: isReentry,
      isInSubprogram: isInSubprogram,
      allVariables: flowchart.variables, // ✅ per type-check
      // 🆕 Guardie runtime: consultano lo stato corrente del DebugBloc al momento dell'esecuzione del comando
      canNext: () {
        final s = context.read<DebugBloc>().state;
        if (s is DebugError && s.isBlocking) return false;
        if (s is DebugInProgress && s.isProcessing) return false;
        if (s is DebugAwaitingInput) {
          // Consenti Next solo se tutte le assegnazioni runtime sono state completate
          final session = s.session;
          if (session.currentIndex >= session.debugPath.length || session.currentIndex < 0) return false;
          final nodeId = session.debugPath[session.currentIndex];
          final node = s.currentFlowchart.nodes.firstWhere(
                (n) => n.id == nodeId,
            orElse: () => throw StateError('Nodo non trovato: $nodeId'),
          );

          // 🔴 MODIFICATO: Controlla InputNode invece di AssignmentNode
          if (node is InputNode) {
            final vars = session.variables;
            final hasPending = node.assignments.any((a) {
              final expr = a.expression.trim();
              if (expr.isNotEmpty) return false; // non è runtime assignment
              final name = a.target.trim();
              final hasValue = vars.containsKey(name) && vars[name] != null;
              return !hasValue; // pending se manca valore
            });
            return !hasPending; // Next consentito solo se nessun pending
          }
          // Per altri nodi in AwaitingInput (eventuali): mantieni Next disabilitato
          return false;
        }
        return true;
      },
      canPrev: () {
        final s = context.read<DebugBloc>().state;
        if (s is DebugAwaitingInput) return false; // non tornare indietro mentre si attende input su questo nodo
        if (s is DebugInProgress) {
          if (s.isProcessing) return false;
          if (s.session.currentIndex <= 0) return false; // 🔒 Prev disabilitato su Start o prima
        }
        return true;
      },
    );
  }

  void _handleHistoryUpdate(List<ConsoleEntry> history) {
    if (!mounted) return;
    setState(() {
      _history = history;
    });
    _scrollToBottom();
  }

  void _handleInput(String input) {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) return;

    _inputController.clear();
    _engine?.handleInput(trimmedInput);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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

    // Ascolta i cambiamenti dello stato del DebugBloc
    return BlocListener<DebugBloc, DebugState>(
      listener: (context, state) {
        if (state is DebugInProgress) {
          // Quando cambia il nodo corrente, reinizializza l'engine
          final session = state.session;
          if (session.currentIndex >= 0 && session.currentIndex < session.debugPath.length) {
            final nodeId = session.debugPath[session.currentIndex];
            FlowNode? currentNode;
            try {
              currentNode = state.currentFlowchart.nodes.firstWhere(
                    (n) => n.id == nodeId,
              );
            } catch (_) {
              currentNode = null;
            }

            if (currentNode == null) {
              // Può succedere temporaneamente dopo un Return: aggiorna engine senza crash
              debugPrint('⚠️ Nodo $nodeId non trovato nel flowchart corrente, reinizializzo engine');
              _initializeEngine();
            } else {
              // Se il nodo è cambiato, reinizializza
              if (_engine?.currentNode.id != currentNode.id) {
                _initializeEngine();
              }
            }
          }

          // 🆕 Propaga il risultato dell'ultimo step nella console
          if (state.lastMessage != null || (state.lastUpdatedVariables != null && state.lastUpdatedVariables!.isNotEmpty)) {
            _engine?.showExecutionResult(
              success: !(state.lastMessageIsError),
              message: state.lastMessage,
              updatedVariables: state.lastUpdatedVariables,
              blocking: state.lastMessageIsBlocking, // ✅ Passa flag bloccante
            );
          }
        } else if (state is DebugAwaitingInput) {
          // In attesa input su nodo (es. Assignment): assicurati che la console sia inizializzata per questo nodo
          final session = state.session;
          if (session.currentIndex >= 0 && session.currentIndex < session.debugPath.length) {
            final nodeId = session.debugPath[session.currentIndex];
            if (_engine?.currentNode.id != nodeId) {
              _initializeEngine();
            }
          }
        } else if (state is DebugError) {
          // Stampa SEMPRE l'errore in console (sfondo rosso)
          _engine?.showError(state.message);
        }
      },
      child: Container(
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
            // Header reattivo: disabilita Next su errore bloccante
            BlocBuilder<DebugBloc, DebugState>(
              builder: (context, dbgState) {
                bool disableNext = false;
                bool disablePrev = false;
                if (dbgState is DebugError && dbgState.isBlocking) {
                  disableNext = true;
                  disablePrev = true;
                } else if (dbgState is DebugAwaitingInput) {
                  // Abilita Next SOLO se tutte le assegnazioni runtime sono state completate
                  final session = dbgState.session;
                  if (session.currentIndex >= 0 && session.currentIndex < session.debugPath.length) {
                    final nodeId = session.debugPath[session.currentIndex];
                    final node = dbgState.currentFlowchart.nodes.firstWhere(
                          (n) => n.id == nodeId,
                      orElse: () => throw StateError('Nodo non trovato: $nodeId'),
                    );

                    // 🔴 MODIFICATO: Controlla InputNode
                    if (node is InputNode) {
                      final vars = session.variables;
                      final hasPending = node.assignments.any((a) {
                        final expr = a.expression.trim();
                        if (expr.isNotEmpty) return false;
                        final name = a.target.trim();
                        final hasValue = vars.containsKey(name) && vars[name] != null;
                        return !hasValue;
                      });
                      disableNext = hasPending;
                    } else {
                      disableNext = true; // altri casi di AwaitingInput
                    }
                  } else {
                    disableNext = true;
                  }
                  disablePrev = true; // Prev disabilitato in attesa input
                } else if (dbgState is DebugInProgress) {
                  if (dbgState.isProcessing) {
                    disableNext = true; // elaborazione in corso: Next disabilitato
                    disablePrev = true; // Prev disabilitato durante elaborazione
                  }
                  // 🔒 Prev disabilitato su indice <= 0 (Start o prima)
                  if (dbgState.session.currentIndex <= 0) {
                    disablePrev = true;
                  }
                }
                return _buildHeader(theme, disableNextNext: disableNext, disablePrevPrev: disablePrev);
              },
            ),
            _buildHistoryArea(theme),
            _buildInputArea(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme, {bool disableNextNext = false, bool disablePrevPrev = false}) {
    return Container(
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
        ],
      ),
    );
  }

  Widget _buildHistoryArea(FluentThemeData theme) {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          return ConsoleEntryWidget(entry: _history[index]);
        },
      ),
    );
  }

  Widget _buildInputArea(FluentThemeData theme) {
    return Container(
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
              placeholder: 'Inserisci i valori richiesti per il nodo Input',
              enabled: true,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 13,
              ),
              onSubmitted: _handleInput,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _handleInput(_inputController.text),
            child: const Text('Invio'),
          ),
        ],
      ),
    );
  }
}
