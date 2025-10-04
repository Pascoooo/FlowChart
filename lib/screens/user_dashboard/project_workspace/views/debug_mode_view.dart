import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import 'debug_console.dart';
import 'workarea.dart';

/// 🐛 Debug Mode View - Modalità di debug con validazione runtime
class DebugModeView extends StatefulWidget {
  final GlobalKey workareaKey;
  final bool showGrid;
  final VoidCallback onToggleGrid;

  const DebugModeView({
    super.key,
    required this.workareaKey,
    required this.showGrid,
    required this.onToggleGrid,
  });

  @override
  State<DebugModeView> createState() => _DebugModeViewState();
}

class _DebugModeViewState extends State<DebugModeView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
      ..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return FadeTransition(
      opacity: _fade,
      child: Row(
        children: [
          // Left Panel - WorkArea with Controls
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: WorkArea(
                    repaintKey: widget.workareaKey,
                    showGrid: widget.showGrid,
                    onToggleGrid: widget.onToggleGrid,
                    isReadOnly: true,
                    allowDragInReadOnly: false, // Disabilita drag in debug
                  ),
                ),

                // Top Left - Step Info Card
                Positioned(
                  top: 24,
                  left: 24,
                  child: _DebugStepInfoCard(),
                ),

                // Top Right - Navigation Controls
                Positioned(
                  top: 24,
                  right: 24,
                  child: _DebugNavigationControls(),
                ),
              ],
            ),
          ),

          // Vertical Divider
          Container(
            width: 1,
            color: theme.resources.dividerStrokeColorDefault,
          ),

          // Right Panel - Details
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: theme.resources.layerFillColorAlt,
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: DebugDetailsPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 📊 Debug Step Info Card (Top Left)
class _DebugStepInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is FlowchartLoaded && state.isDebugMode) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.accentColor.defaultBrushFor(theme.brightness),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor
                      .defaultBrushFor(theme.brightness)
                      .withValues(alpha: 0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.locationDot,
                  size: 16,
                  color: theme.brightness == Brightness.light
                      ? Colors.white
                      : Colors.black,
                ),
                const SizedBox(width: 10),
                Text(
                  'Step ${state.debugIndex + 1} / ${state.debugPath.length}',
                  style: TextStyle(
                    color: theme.brightness == Brightness.light
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// 🎮 Debug Navigation Controls (Top Right) - CON VALIDAZIONE RUNTIME
class _DebugNavigationControls extends StatelessWidget {
  const _DebugNavigationControls();

  // Helper: sostituisce variabili e valuta la condizione (supporta =, ==, !=, >=, <=, >, <, &&, ||, !, parentesi)
  bool _evaluateDecision(String condition, Map<String, dynamic> variables) {
    String evaluable = condition;
    for (final entry in variables.entries) {
      final key = entry.key;
      final value = entry.value;
      final valueStr = (value is bool) ? (value ? 'true' : 'false') : value.toString();
      evaluable = evaluable.replaceAll('{$key}', valueStr);
      evaluable = evaluable.replaceAllMapped(
        RegExp(r'\b' + RegExp.escape(key) + r'\b'),
        (m) => valueStr,
      );
    }
    evaluable = _sanitize(evaluable);
    final res = _evalExpr(evaluable);
    return (res is bool) ? res : (res is num ? res != 0 : false);
  }

  String _sanitize(String s) {
    var out = s.trim();
    if (out.endsWith(';')) out = out.substring(0, out.length - 1).trim();
    out = out.replaceAll(RegExp(r'\bAND\b', caseSensitive: false), '&&');
    out = out.replaceAll(RegExp(r'\bOR\b', caseSensitive: false), '||');
    out = out.replaceAll(RegExp(r'\bNOT\b', caseSensitive: false), '!');

    out = out
        .replaceAll('>=', '__GE__')
        .replaceAll('<=', '__LE__')
        .replaceAll('!=', '__NE__')
        .replaceAll('==', '__EQ__');
    out = out.replaceAll('=', '==');
    out = out
        .replaceAll('__GE__', '>=')
        .replaceAll('__LE__', '<=')
        .replaceAll('__NE__', '!=')
        .replaceAll('__EQ__', '==');

    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }

  dynamic _evalExpr(String expression) {
    var expr = expression.trim();
    if (expr.toLowerCase() == 'true') return true;
    if (expr.toLowerCase() == 'false') return false;
    final n = num.tryParse(expr);
    if (n != null) return n;

    expr = _stripOuter(expr);

    final orSplit = _splitTop(expr, '||');
    if (orSplit != null) {
      final l = _evalExpr(orSplit[0]);
      final r = _evalExpr(orSplit[1]);
      return ((l is bool) ? l : (l != 0)) || ((r is bool) ? r : (r != 0));
    }
    final andSplit = _splitTop(expr, '&&');
    if (andSplit != null) {
      final l = _evalExpr(andSplit[0]);
      final r = _evalExpr(andSplit[1]);
      return ((l is bool) ? l : (l != 0)) && ((r is bool) ? r : (r != 0));
    }
    if (expr.startsWith('!')) {
      final v = _evalExpr(expr.substring(1).trim());
      return !((v is bool) ? v : (v != 0));
    }

    for (final op in const ['>=', '<=', '==', '!=']) {
      final parts = _splitTop(expr, op);
      if (parts != null) {
        final l = _evalExpr(parts[0]);
        final r = _evalExpr(parts[1]);
        switch (op) {
          case '>=':
            return (l is num && r is num && l >= r) ? 1 : 0;
          case '<=':
            return (l is num && r is num && l <= r) ? 1 : 0;
          case '==':
            return (l == r) ? 1 : 0;
          case '!=':
            return (l != r) ? 1 : 0;
        }
      }
    }
    for (final op in const ['>', '<']) {
      final parts = _splitTop(expr, op);
      if (parts != null) {
        final l = _evalExpr(parts[0]);
        final r = _evalExpr(parts[1]);
        switch (op) {
          case '>':
            return (l is num && r is num && l > r) ? 1 : 0;
          case '<':
            return (l is num && r is num && l < r) ? 1 : 0;
        }
      }
    }
    return 0;
  }

  String _stripOuter(String s) {
    while (s.length >= 2 && s.startsWith('(') && s.endsWith(')')) {
      var depth = 0; var all = true;
      for (int i = 0; i < s.length; i++) {
        final c = s[i];
        if (c == '(') depth++;
        if (c == ')') { depth--; if (depth == 0 && i != s.length - 1) { all = false; break; } }
      }
      if (all) { s = s.substring(1, s.length - 1).trim(); } else { break; }
    }
    return s;
  }

  List<String>? _splitTop(String s, String op) {
    int depth = 0;
    for (int i = 0; i <= s.length - op.length; i++) {
      final c = s[i];
      if (c == '(') depth++; else if (c == ')') { depth--; if (depth < 0) depth = 0; }
      if (depth == 0 && s.substring(i, i + op.length) == op) {
        final left = s.substring(0, i).trim();
        final right = s.substring(i + op.length).trim();
        return [left, right];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is! FlowchartLoaded || !state.isDebugMode) {
          return const SizedBox.shrink();
        }

        final canPrev = state.debugIndex > 0;
        final projectRepo = context.read<ProjectBloc>().projectRepository;

        // Ottieni il nodo corrente per la validazione
        FlowNode? currentNode;
        if (state.debugIndex < state.debugPath.length) {
          final currentNodeId = state.debugPath[state.debugIndex];
          currentNode = state.getNodeById(currentNodeId);
        }

        return StreamBuilder<Map<String, dynamic>>(
          stream: projectRepo.watchDebugVariables(projectId: state.flowchart.flowchartId),
          builder: (context, snapshot) {
            final variables = snapshot.data ?? {};

            // Determina se possiamo avanzare in base alle variabili
            bool canNext = false;
            String disabledReason = 'Caricamento...';

            if (state.debugIndex < (state.debugPath.length - 1) && currentNode != null) {
              final validationResult = _validateNodeCompletion(currentNode, variables, state.flowchart.variables);
              canNext = validationResult.isValid;
              disabledReason = validationResult.reason;
            }

            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.resources.layerFillColorDefault,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.resources.cardStrokeColorDefault,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Previous Step
                  Tooltip(
                    message: 'Passo precedente (←)',
                    child: IconButton(
                      icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 16),
                      onPressed: canPrev
                          ? () => context.read<FlowchartBloc>().add(const DebugPrevNode())
                          : null,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Next Step con validazione e branching
                  Tooltip(
                    message: canNext ? 'Passo successivo (→)' : disabledReason,
                    child: FilledButton(
                      onPressed: canNext
                          ? () {
                              if (currentNode is DecisionNode) {
                                final res = _evaluateDecision((currentNode as DecisionNode).condition, variables);
                                context.read<FlowchartBloc>().add(DebugBranchSelected(res));
                              } else {
                                context.read<FlowchartBloc>().add(const DebugNextNode());
                              }
                            }
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Avanti'),
                          SizedBox(width: 6),
                          FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: theme.resources.dividerStrokeColorDefault,
                  ),

                  // Exit Button
                  Tooltip(
                    message: 'Esci dalla modalità debug (Esc)',
                    child: Button(
                      onPressed: () => context.read<FlowchartBloc>().add(const DebugExit()),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          final baseColor = theme.resources.systemFillColorCritical
                              .withValues(alpha: 0.1);
                          if (states.contains(WidgetState.hovered)) {
                            return theme.resources.systemFillColorCritical
                                .withValues(alpha: 0.2);
                          }
                          if (states.contains(WidgetState.pressed)) {
                            return theme.resources.systemFillColorCritical
                                .withValues(alpha: 0.25);
                          }
                          return baseColor;
                        }),
                        foregroundColor: WidgetStateProperty.all(
                          theme.resources.systemFillColorCritical,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.xmark,
                            size: 16,
                            color: theme.resources.systemFillColorCritical,
                          ),
                          const SizedBox(width: 8),
                          const Text('Esci'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Valida se il nodo corrente è stato completato correttamente
  _ValidationResult _validateNodeCompletion(
    FlowNode node,
    Map<String, dynamic> currentVariables,
    List<VariableDeclaration> allVariables,
  ) {
    switch (node.kind) {
      case FlowNodeKind.input:
        // Il blocco INPUT deve solo DICHIARARE le variabili nella tabella
        // Non richiede alcun valore - quelli verranno assegnati tramite ASSIGNMENT
        final inputNode = node as InputNode;
        for (final varName in inputNode.targetVariables) {
          if (!currentVariables.containsKey(varName)) {
            return _ValidationResult(false, 'Aggiungi la variabile "$varName" alla tabella');
          }
        }
        return _ValidationResult(true, 'Variabili di input dichiarate');

      case FlowNodeKind.output:
        // OUTPUT ora si comporta come ASSIGNMENT: richiede valori VALIDI per tutte le variabili
        final outputNode = node as OutputNode;
        for (final variable in outputNode.variables) {
          if (!currentVariables.containsKey(variable.name)) {
            return _ValidationResult(false, 'Inserisci un valore per "${variable.name}" prima di stampare');
          }
          final value = currentVariables[variable.name];
          if (value == null || (value is String && value.isEmpty)) {
            return _ValidationResult(false, 'La variabile "${variable.name}" necessita di un valore valido');
          }
        }
        return _ValidationResult(true, 'Tutte le variabili di output hanno valori validi');

      case FlowNodeKind.assignment:
        // ASSIGNMENT richiede che ogni variabile assegnata abbia un valore VALIDO (non vuoto)
        final assignmentNode = node as AssignmentNode;
        for (final assignment in assignmentNode.assignments) {
          if (!currentVariables.containsKey(assignment.target)) {
            return _ValidationResult(false, 'Assegna un valore a "${assignment.target}"');
          }
          final value = currentVariables[assignment.target];
          if (value == null || (value is String && value.isEmpty)) {
            return _ValidationResult(false, 'Valore non valido per "${assignment.target}"');
          }
        }
        return _ValidationResult(true, 'Tutte le assegnazioni sono state effettuate');

      case FlowNodeKind.decision:
        // DECISION verifica che tutte le variabili di LAVORO nella condizione abbiano un valore runtime VALIDO
        final decisionNode = node as DecisionNode;
        final varsInCondition = _extractVariablesFromCondition(decisionNode.condition, allVariables);
        for (final varName in varsInCondition) {
          final varDecl = allVariables.firstWhere(
            (v) => v.name == varName,
            orElse: () => const VariableDeclaration(name: '', dataType: 'string'),
          );

          // Solo le variabili di LAVORO (local) richiedono valore runtime nella condizione
          // Le variabili input/output possono essere già state valorizzate
          if (varDecl.scope == VariableScope.local || !currentVariables.containsKey(varName)) {
            if (!currentVariables.containsKey(varName)) {
              return _ValidationResult(false, 'La variabile di lavoro "$varName" deve essere dichiarata');
            }
            final value = currentVariables[varName];
            if (value == null || (value is String && value.isEmpty)) {
              return _ValidationResult(false, 'Assegna un valore runtime a "$varName" per valutare la condizione');
            }
          }
        }
        return _ValidationResult(true, 'Tutte le variabili della condizione hanno un valore');

      default:
        return _ValidationResult(true, 'Nodo completato');
    }
  }

  /// Estrae i nomi delle variabili da una condizione
  List<String> _extractVariablesFromCondition(String condition, List<VariableDeclaration> allVariables) {
    final List<String> foundVariables = [];
    for (final variable in allVariables) {
      // Cerca il nome della variabile come parola intera
      final pattern = RegExp(r'\b' + RegExp.escape(variable.name) + r'\b');
      if (pattern.hasMatch(condition)) {
        foundVariables.add(variable.name);
      }
    }
    return foundVariables;
  }
}

/// Classe helper per il risultato della validazione
class _ValidationResult {
  final bool isValid;
  final String reason;

  _ValidationResult(this.isValid, this.reason);
}

/// 📋 Debug Details Panel (Right Side)
class DebugDetailsPanel extends StatefulWidget {
  const DebugDetailsPanel({super.key});

  @override
  State<DebugDetailsPanel> createState() => _DebugDetailsPanelState();
}

class _DebugDetailsPanelState extends State<DebugDetailsPanel> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is! FlowchartLoaded || !state.isDebugMode) {
          return const SizedBox.shrink();
        }

        final currentNodeId = state.selectedNodeId;
        if (currentNodeId == null) return const SizedBox.shrink();

        final currentNode = state.getNodeById(currentNodeId);
        if (currentNode == null) return const SizedBox.shrink();

        return Column(
          children: [
            // Custom Tab Header
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.resources.cardBackgroundFillColorDefault,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.resources.cardStrokeColorDefault,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      icon: FontAwesomeIcons.clipboardList,
                      label: 'Stato Attuale',
                      isSelected: _selectedTab == 0,
                      onPressed: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _TabButton(
                      icon: FontAwesomeIcons.timeline,
                      label: 'Percorso',
                      isSelected: _selectedTab == 1,
                      onPressed: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: _selectedTab == 0
                  ? _buildStateTab(context, theme, state, currentNode)
                  : _buildTraceTab(context, theme, state),
            ),

            // 🆕 CONSOLE INTERATTIVA - Sempre visibile sotto
            SizedBox(
              height: 300,
              child: DebugConsole(
                currentNode: currentNode,
                flowchartId: state.flowchart.flowchartId,
                projectRepo: context.read<ProjectBloc>().projectRepository,
                allVariables: state.flowchart.variables,
                onCommandExecuted: () {
                  // Callback quando l'esecuzione è completata
                  setState(() {});
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 📊 State Tab - Current Node Details with Runtime Validation
  Widget _buildStateTab(
    BuildContext context,
    FluentThemeData theme,
    FlowchartLoaded state,
    FlowNode currentNode,
  ) {
    final projectRepo = context.read<ProjectBloc>().projectRepository;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.resources.cardStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.accentColor
                        .defaultBrushFor(theme.brightness)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FaIcon(
                    _getNodeIcon(currentNode.kind),
                    size: 18,
                    color:
                        theme.accentColor.defaultBrushFor(theme.brightness),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${state.debugIndex + 1}',
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentNode.text,
                        style: theme.typography.subtitle?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Node Details Expander
          _DebugExpander(
            title: 'Dettagli Nodo',
            icon: FontAwesomeIcons.circleInfo,
            initiallyExpanded: true,
            child: Column(
              children: _buildNodeDetails(context, theme, currentNode),
            ),
          ),

          const SizedBox(height: 12),

          // Runtime Execution Section (NUOVO!)
          if (_requiresRuntimeInput(currentNode))
            _buildRuntimeExecutionSection(
                context, theme, state, currentNode, projectRepo),

          const SizedBox(height: 12),

          // Session Variables Expander
          _DebugExpander(
            title: 'Variabili di Sessione',
            icon: FontAwesomeIcons.database,
            initiallyExpanded: true,
            child: StreamBuilder<Map<String, dynamic>>(
              stream: projectRepo.watchDebugVariables(
                  projectId: state.flowchart.flowchartId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: ProgressRing(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErrorState(
                    context,
                    'Errore caricamento variabili: ${snapshot.error}',
                  );
                }

                final variables = snapshot.data ?? {};

                // 🆕 Filtra le variabili in base allo stato corrente
                final currentNodeKind = currentNode.kind;
                final debugIndex = state.debugIndex;

                final filteredEntries = variables.entries.where((entry) {
                  final decl = state.flowchart.variables.firstWhere(
                      (v) => v.name == entry.key,
                      orElse: () => const VariableDeclaration(name: '_', dataType: 'string'));

                  if (decl.name == '_') return true; // non dichiarata, mostra per debug

                  // Le variabili OUTPUT sono visibili SOLO nel nodo output o dopo
                  if (decl.scope == VariableScope.output) {
                    // Cerca se abbiamo già passato un nodo OUTPUT che usa questa variabile
                    bool hasPassedOutputNode = false;
                    for (int i = 0; i <= debugIndex; i++) {
                      final nodeId = state.debugPath[i];
                      final node = state.getNodeById(nodeId);
                      if (node is OutputNode && node.variables.any((v) => v.name == entry.key)) {
                        hasPassedOutputNode = true;
                        break;
                      }
                    }
                    return hasPassedOutputNode || currentNodeKind == FlowNodeKind.output;
                  }

                  // 🆕 Le variabili di LAVORO sono visibili SOLO dopo aver passato un nodo DECISION che le usa
                  if (decl.scope == VariableScope.local) {
                    // Cerca se abbiamo già passato un nodo DECISION che usa questa variabile
                    bool hasPassedDecisionNode = false;
                    for (int i = 0; i <= debugIndex; i++) {
                      final nodeId = state.debugPath[i];
                      final node = state.getNodeById(nodeId);
                      if (node is DecisionNode) {
                        final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b');
                        if (pattern.hasMatch(node.condition)) {
                          hasPassedDecisionNode = true;
                          break;
                        }
                      }
                    }
                    return hasPassedDecisionNode || currentNodeKind == FlowNodeKind.decision;
                  }

                  return true; // Variabili input sempre visibili
                }).toList();

                if (filteredEntries.isEmpty) {
                  return _buildEmptyVariablesState(context);
                }

                return Column(
                  children: filteredEntries.map((entry) {
                    return _VariableRow(
                      name: entry.key,
                      value: entry.value.toString(),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 Runtime Execution Section (NUOVO!)
  Widget _buildRuntimeExecutionSection(
    BuildContext context,
    FluentThemeData theme,
    FlowchartLoaded state,
    FlowNode currentNode,
    dynamic projectRepo,
  ) {
    // Rimosso - sostituito dalla console interattiva
    return const SizedBox.shrink();
  }

  /// 🗺️ Trace Tab - Execution Path
  Widget _buildTraceTab(
    BuildContext context,
    FluentThemeData theme,
    FlowchartLoaded state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.resources.cardStrokeColorDefault,
            ),
          ),
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.listCheck,
                size: 18,
                color: theme.accentColor.defaultBrushFor(theme.brightness),
              ),
              const SizedBox(width: 12),
              Text(
                'Traccia Esecuzione',
                style: theme.typography.subtitle?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.accentColor
                      .defaultBrushFor(theme.brightness)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.debugPath.length} steps',
                  style: TextStyle(
                    color:
                        theme.accentColor.defaultBrushFor(theme.brightness),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Execution Steps List
        Expanded(
          child: ListView.builder(
            itemCount: state.debugPath.length,
            itemBuilder: (context, index) {
              final nodeId = state.debugPath[index];
              final node = state.getNodeById(nodeId);
              if (node == null) return const SizedBox.shrink();

              final bool isCurrent = index == state.debugIndex;
              final bool isPast = index < state.debugIndex;

              return _ExecutionStep(
                index: index,
                node: node,
                isCurrent: isCurrent,
                isPast: isPast,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 🔧 Build Node Details
  List<Widget> _buildNodeDetails(
    BuildContext context,
    FluentThemeData theme,
    FlowNode node,
  ) {
    switch (node.kind) {
      case FlowNodeKind.input:
        final input = node as InputNode;
        if (input.targetVariables.isEmpty) {
          return [
            _buildEmptyState(context, 'Nessuna variabile da leggere'),
          ];
        }
        return input.targetVariables.map((varName) {
          return _DetailRow(
            label: 'Legge',
            value: varName,
            isCode: true,
          );
        }).toList();

      case FlowNodeKind.assignment:
        final assignmentNode = node as AssignmentNode;
        if (assignmentNode.assignments.isEmpty) {
          return [_buildEmptyState(context, 'Nessuna assegnazione definita')];
        }
        return assignmentNode.assignments.map((a) {
          return _DetailRow(
            label: 'Assegna',
            value: '${a.target} = ${a.expression}',
            isCode: true,
          );
        }).toList();

      case FlowNodeKind.output:
        final out = node as OutputNode;
        return [
          _DetailRow(label: 'Template', value: out.template, isCode: true),
          _DetailRow(
              label: 'Variabili', value: out.variables.join(', '), isCode: true),
        ];

      case FlowNodeKind.process:
        final p = node as ProcessNode;
        return [
          _DetailRow(label: 'Chiama', value: p.flowchartToCall, isCode: true),
          _DetailRow(
              label: 'Argomenti', value: p.arguments.join(', '), isCode: true),
          _DetailRow(
              label: 'Risultato',
              value: p.resultTarget?.toString() ?? 'Nessuno',
              isCode: true),
        ];

      case FlowNodeKind.decision:
        final d = node as DecisionNode;
        return [
          _DetailRow(label: 'Condizione', value: d.condition, isCode: true),
        ];

      default:
        return [
          _DetailRow(label: 'Testo', value: node.text),
        ];
    }
  }

  /// 🎨 Helper: Get Node Icon
  IconData _getNodeIcon(FlowNodeKind kind) {
    return switch (kind) {
      FlowNodeKind.start => FontAwesomeIcons.play,
      FlowNodeKind.end => FontAwesomeIcons.flagCheckered,
      FlowNodeKind.input => FontAwesomeIcons.keyboard,
      FlowNodeKind.output => FontAwesomeIcons.terminal,
      FlowNodeKind.process => FontAwesomeIcons.gears,
      FlowNodeKind.decision => FontAwesomeIcons.codeBranch,
      FlowNodeKind.assignment => FontAwesomeIcons.penToSquare,
    };
  }

  /// 🎨 Helper: Check if node requires runtime input
  bool _requiresRuntimeInput(FlowNode node) {
    // OUTPUT ora richiede l'inserimento dei valori (come assignment) se ha variabili
    if (node.kind == FlowNodeKind.output) {
      final out = node as OutputNode;
      return out.variables.isNotEmpty;
    }
    if (node.kind == FlowNodeKind.input) return false;
    return node.kind == FlowNodeKind.assignment || node.kind == FlowNodeKind.decision;
  }

  /// 🎨 Empty Variables State
  Widget _buildEmptyVariablesState(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          children: [
            FaIcon(
              FontAwesomeIcons.boxOpen,
              size: 24,
              color: theme.resources.textFillColorTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              'Nessuna variabile in questo scope',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎨 Error State
  Widget _buildErrorState(BuildContext context, String message) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.triangleExclamation,
            size: 16,
            color: theme.resources.systemFillColorCritical,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(
                color: theme.resources.systemFillColorCritical,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎨 Empty State
  Widget _buildEmptyState(BuildContext context, String message) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// 🎯 Runtime Execution Form (NUOVO! - Con validazione)
class _RuntimeExecutionForm extends StatefulWidget {
  final FlowNode node;
  final String flowchartId;
  final dynamic projectRepo;
  final List<VariableDeclaration> allVariables;

  const _RuntimeExecutionForm({
    required this.node,
    required this.flowchartId,
    required this.projectRepo,
    required this.allVariables,
  });

  @override
  State<_RuntimeExecutionForm> createState() => _RuntimeExecutionFormState();
}

class _RuntimeExecutionFormState extends State<_RuntimeExecutionForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _errors = {};
  bool _isExecuting = false;
  bool _assignmentCompleted = false;
  bool _outputCompleted = false;
  String? _renderedOutput;

  @override
  void initState() {
    super.initState();
    // 1. Chiama il nuovo metodo di setup all'inizio
    _setupControllersForNode(widget.node);
  }

  @override
  void didUpdateWidget(covariant _RuntimeExecutionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 2. Controlla se il nodo è effettivamente cambiato
    if (widget.node.id != oldWidget.node.id) {
      // 3. Se è cambiato, riesegui il setup
      _setupControllersForNode(widget.node);
    }
  }

  /// Pulisce i vecchi controller e ne crea di nuovi per il nodo corrente.
  void _setupControllersForNode(FlowNode node) {
    // Pulisce i controller precedenti per evitare memory leak
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _errors.clear();
    setState(() {
      _outputCompleted = false;
      _assignmentCompleted = false;
      _renderedOutput = null;
    });

    // Inizializza i nuovi controller in base al tipo di nodo
    // (Questa logica è la stessa che avevi in _initializeControllers)
    if (node is OutputNode) {
      for (final variable in node.variables) {
        _controllers[variable.name] = TextEditingController();
      }
    } else if (node is AssignmentNode) {
      for (final assignment in node.assignments) {
        _controllers[assignment.target] = TextEditingController();
      }
    } else if (node is DecisionNode) {
      final varsInCondition = _extractVariablesFromCondition(node.condition);
      for (final varName in varsInCondition) {
        _controllers[varName] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    // Assicurati che tutti i controller siano deallocati quando il widget viene rimosso
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  /// Estrae le variabili da una condizione
  List<String> _extractVariablesFromCondition(String condition) {
    final List<String> foundVariables = [];
    for (final variable in widget.allVariables) {
      final pattern = RegExp(r'\b' + RegExp.escape(variable.name) + r'\b');
      if (pattern.hasMatch(condition)) {
        foundVariables.add(variable.name);
      }
    }
    return foundVariables;
  }

  /// Valida il valore in base al tipo di dato
  String? _validateValue(String varName, String value) {
    final variable = widget.allVariables.firstWhere(
      (v) => v.name == varName,
      orElse: () => VariableDeclaration(
          name: varName, dataType: 'string', scope: VariableScope.local),
    );

    if (value.trim().isEmpty) {
      return 'Il valore non può essere vuoto';
    }

    switch (variable.dataType.toLowerCase()) {
      case 'int':
      case 'integer':
        if (int.tryParse(value) == null) {
          return 'Deve essere un numero intero';
        }
        break;
      case 'double':
      case 'float':
      case 'number':
        if (double.tryParse(value) == null) {
          return 'Deve essere un numero';
        }
        break;
      case 'bool':
      case 'boolean':
        if (value.toLowerCase() != 'true' && value.toLowerCase() != 'false') {
          return 'Deve essere true o false';
        }
        break;
      case 'string':
        // Le stringhe sono sempre valide
        break;
      default:
        break;
    }

    return null;
  }

  /// 🆕 VALUE RESOLVER - Risolve espressioni, variabili e letterali
  /// Restituisce un oggetto con il valore risolto o un errore
  ///
  /// SINTASSI:
  /// - {nomeVariabile}  → usa il valore della variabile dalla sessione
  /// - 100              → numero letterale
  /// - testo            → stringa letterale
  /// - {a} + {b}        → espressione con variabili
  Future<ResolvedValue> _resolveValue(String input, String targetVarName) async {
    final trimmedInput = input.trim();

    if (trimmedInput.isEmpty) {
      return ResolvedValue.error('Input vuoto');
    }

    // Ottieni le variabili di sessione correnti
    final sessionVars = await widget.projectRepo.getDebugVariables(
      projectId: widget.flowchartId,
    );

    // Verifica se contiene riferimenti a variabili {nome}
    final varPattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    final hasVariables = varPattern.hasMatch(trimmedInput);

    if (hasVariables) {
      // Estrai tutte le variabili referenziate
      final varMatches = varPattern.allMatches(trimmedInput);
      final referencedVars = <String>[];

      for (final match in varMatches) {
        final varName = match.group(1)!;
        referencedVars.add(varName);

        // Verifica che la variabile esista e abbia un valore
        if (!sessionVars.containsKey(varName)) {
          return ResolvedValue.error(
            'Variabile "$varName" non trovata. Usa "{$varName}" solo per variabili esistenti.'
          );
        }

        final value = sessionVars[varName];
        if (value == null || (value is String && value.isEmpty)) {
          return ResolvedValue.error(
            'Variabile "$varName" non ha un valore assegnato.'
          );
        }
      }

      // Se è solo "{nome}" senza operazioni, restituisci direttamente il valore
      if (trimmedInput == '{${referencedVars.first}}' && referencedVars.length == 1) {
        return ResolvedValue.success(sessionVars[referencedVars.first]!, isLiteral: false);
      }

      // Altrimenti è un'espressione - sostituisci le variabili e valuta
      String processedExpression = trimmedInput;

      for (final varName in referencedVars) {
        final value = sessionVars[varName];
        // Sostituisci {nome} con il valore
        processedExpression = processedExpression.replaceAll(
          '{$varName}',
          value.toString(),
        );
      }

      // Verifica se contiene operatori matematici
      final hasOperators = RegExp(r'[+\-*/()%]').hasMatch(processedExpression);

      if (hasOperators) {
        // Valuta l'espressione matematica
        try {
          final parser = GrammarParser();
          final exp = parser.parse(processedExpression);
          final evaluator = RealEvaluator();
          final result = evaluator.evaluate(exp);
          return ResolvedValue.success(result, isLiteral: false);
        } catch (e) {
          return ResolvedValue.error('Errore nella valutazione: ${e.toString()}');
        }
      } else {
        // Se non ci sono operatori, tratta come valore semplice
        return ResolvedValue.success(processedExpression, isLiteral: false);
      }
    }

    // Nessuna variabile referenziata - tratta come letterale

    // Tentativo di parsing come numero intero
    final intValue = int.tryParse(trimmedInput);
    if (intValue != null) {
      return ResolvedValue.success(intValue, isLiteral: true);
    }

    // Tentativo di parsing come numero decimale
    final doubleValue = double.tryParse(trimmedInput);
    if (doubleValue != null) {
      return ResolvedValue.success(doubleValue, isLiteral: true);
    }

    // Tentativo come booleano
    if (trimmedInput.toLowerCase() == 'true') {
      return ResolvedValue.success(true, isLiteral: true);
    }
    if (trimmedInput.toLowerCase() == 'false') {
      return ResolvedValue.success(false, isLiteral: true);
    }

    // Altrimenti, tratta come stringa letterale
    return ResolvedValue.success(trimmedInput, isLiteral: true);
  }

  /// Estrae i nomi delle variabili da un'espressione matematica
  List<String> _extractVariablesFromExpression(String expression) {
    final foundVars = <String>[];

    // Cerca pattern {nome}
    final varPattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    final matches = varPattern.allMatches(expression);

    for (final match in matches) {
      final varName = match.group(1)!;
      if (!foundVars.contains(varName)) {
        foundVars.add(varName);
      }
    }

    return foundVars;
  }

  /// Converte un valore risolto nel tipo target con validazione
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
        throw Exception('Impossibile convertire "$resolvedValue" in integer');

      case 'double':
      case 'float':
      case 'number':
        if (resolvedValue is double) return resolvedValue;
        if (resolvedValue is int) return resolvedValue.toDouble();
        if (resolvedValue is String) {
          final parsed = double.tryParse(resolvedValue);
          if (parsed != null) return parsed;
        }
        throw Exception('Impossibile convertire "$resolvedValue" in number');

      case 'bool':
      case 'boolean':
        if (resolvedValue is bool) return resolvedValue;
        if (resolvedValue is String) {
          if (resolvedValue.toLowerCase() == 'true') return true;
          if (resolvedValue.toLowerCase() == 'false') return false;
        }
        throw Exception('Impossibile convertire "$resolvedValue" in boolean');

      case 'string':
      default:
        return resolvedValue.toString();
    }
  }

  /// Esegue il nodo corrente
  Future<void> _executeNode() async {
    setState(() { _errors.clear(); _isExecuting = true; });
    try {
      if (widget.node is OutputNode) {
        await _executeOutputNode();
      } else if (widget.node is AssignmentNode) {
        await _executeAssignmentNode();
      } else if (widget.node is DecisionNode) {
        await _executeDecisionNode();
      }
    } catch (e) {
      if (mounted) setState(() { _errors['general'] = e.toString(); });
    } finally {
      if (mounted) setState(() { _isExecuting = false; });
    }
  }

  /// Esegue un nodo Output
  Future<void> _executeOutputNode() async {
    final outputNode = widget.node as OutputNode;
    setState(() { _outputCompleted = false; _renderedOutput = null; });

    // Stato attuale delle variabili per eventuale prefill
    final currentVars = await widget.projectRepo.getDebugVariables(projectId: widget.flowchartId);

    bool hasErrors = false;
    final Map<String, dynamic> newValues = {};

    for (final variable in outputNode.variables) {
      final name = variable.name;
      final controller = _controllers[name];
      final existing = currentVars[name];
      final raw = controller?.text.trim() ?? '';

      // Se controller vuoto ma esiste già un valore non vuoto in sessione, usa quello esistente
      if (raw.isEmpty && existing != null && (existing is! String || existing.isNotEmpty)) {
        newValues[name] = existing;
        continue;
      }

      if (raw.isEmpty) {
        setState(() { _errors[name] = 'Valore obbligatorio'; });
        hasErrors = true;
        continue;
      }

      // 🆕 USA IL VALUE RESOLVER per risolvere l'input
      final resolved = await _resolveValue(raw, name);

      if (resolved.error != null) {
        setState(() { _errors[name] = resolved.error!; });
        hasErrors = true;
        continue;
      }

      // Converti il valore risolto nel tipo target
      try {
        final varDecl = widget.allVariables.firstWhere(
          (v) => v.name == name,
          orElse: () => VariableDeclaration(name: name, dataType: 'string'),
        );
        newValues[name] = _convertResolvedValue(resolved.value, varDecl.dataType);
      } catch (e) {
        setState(() { _errors[name] = e.toString(); });
        hasErrors = true;
        continue;
      }
    }

    if (hasErrors) return;

    // 🆕 PERSISTENZA: Salva SEMPRE i valori in sessione
    if (newValues.isNotEmpty) {
      await widget.projectRepo.updateDebugVariables(
        projectId: widget.flowchartId,
        variables: newValues,
      );
    }

    // Rileggi le variabili aggiornate per il rendering
    final merged = await widget.projectRepo.getDebugVariables(projectId: widget.flowchartId);

    // 🆕 FIX RENDERING: usa la funzione corretta
    _renderedOutput = _renderTemplate(outputNode.template, merged);

    if (mounted) setState(() { _outputCompleted = true; });
  }

  /// Esegue un nodo Assignment
  Future<void> _executeAssignmentNode() async {
    final assignmentNode = widget.node as AssignmentNode;

    // Reset stato precedente
    setState(() { _assignmentCompleted = false; });

    bool hasErrors = false;
    final Map<String, dynamic> newValues = {};

    for (final assignment in assignmentNode.assignments) {
      final target = assignment.target;
      final controller = _controllers[target];
      final raw = controller?.text.trim() ?? '';

      if (raw.isEmpty) {
        setState(() { _errors[target] = 'Il valore è obbligatorio'; });
        hasErrors = true; continue;
      }

      final typeError = _validateValue(target, raw);
      if (typeError != null) {
        setState(() { _errors[target] = typeError; });
        hasErrors = true; continue;
      }

      final varDecl = widget.allVariables.firstWhere(
        (v) => v.name == target,
        orElse: () => VariableDeclaration(name: target, dataType: 'string'),
      );
      newValues[target] = _convertValue(raw, varDecl.dataType);
    }

    if (hasErrors) return;

    await widget.projectRepo.updateDebugVariables(
      projectId: widget.flowchartId,
      variables: newValues,
    );

    if (mounted) {
      setState(() { _assignmentCompleted = true; });
      // NON avanziamo: il tasto Avanti in alto diventerà attivo grazie alla validazione globale
    }
  }

  /// Esegue un nodo Decision
  Future<void> _executeDecisionNode() async {
    final decisionNode = widget.node as DecisionNode;

    // Ottieni le variabili correnti
    final currentVars = await widget.projectRepo
        .getDebugVariables(projectId: widget.flowchartId);

    // Prepara eventuali nuovi valori runtime per le variabili mancanti/invalid
    final Map<String, dynamic> newValues = {};
    final varsInCondition = _extractVariablesFromCondition(decisionNode.condition);

    for (final varName in varsInCondition) {
      final controller = _controllers[varName];
      final currentValue = currentVars[varName];
      final needsInput = currentValue == null || (currentValue is String && currentValue.isEmpty);
      if (needsInput) {
        if (controller == null || controller.text.trim().isEmpty) {
          setState(() {
            _errors[varName] = 'Valore richiesto';
          });
          return; // interrompe esecuzione se manca un valore
        } else {
          final validationError = _validateValue(varName, controller.text.trim());
          if (validationError != null) {
            setState(() {
              _errors[varName] = validationError;
            });
            return;
          }
          final varDecl = widget.allVariables.firstWhere(
              (v) => v.name == varName,
              orElse: () => VariableDeclaration(name: varName, dataType: 'string'));
          newValues[varName] = _convertValue(controller.text.trim(), varDecl.dataType);
        }
      }
    }

    // Se ci sono nuovi valori validi aggiorniamo
    if (newValues.isNotEmpty) {
      await widget.projectRepo.updateDebugVariables(
        projectId: widget.flowchartId,
        variables: newValues,
      );
    }

    // Rileggi le variabili aggiornate per la valutazione
    final mergedVars = await widget.projectRepo
        .getDebugVariables(projectId: widget.flowchartId);

    try {
      final result = _evaluateCondition(decisionNode.condition, mergedVars);
      if (mounted) {
        // manda evento con il ramo da seguire
        context.read<FlowchartBloc>().add(DebugBranchSelected(result));
      }
    } catch (e) {
      setState(() {
        _errors['condition'] = 'Errore nella valutazione: ${e.toString()}';
      });
    }
  }

  /// Converte una stringa nel tipo corretto
  dynamic _convertValue(String value, String dataType) {
    switch (dataType.toLowerCase()) {
      case 'int':
      case 'integer':
        return int.parse(value);
      case 'double':
      case 'float':
      case 'number':
        return double.parse(value);
      case 'bool':
      case 'boolean':
        return value.toLowerCase() == 'true';
      case 'string':
      default:
        return value;
    }
  }

  /// Valuta un'espressione matematica usando math_expressions
  dynamic _evaluateExpression(
      String expression, Map<String, dynamic> variables) {
    try {
      // Sostituisci le variabili con i loro valori nell'espressione
      String processedExpression = expression;
      for (final entry in variables.entries) {
        processedExpression = processedExpression.replaceAll(
          entry.key,
          entry.value.toString(),
        );
      }

      final parser = GrammarParser();
      final exp = parser.parse(processedExpression);
      final evaluator = RealEvaluator();

      return evaluator.evaluate(exp);
    } catch (e) {
      throw Exception('Espressione non valida: $expression');
    }
  }

  /// Valuta una condizione booleana
  bool _evaluateCondition(String condition, Map<String, dynamic> variables) {
    // Sostituisci le variabili con i loro valori (supporta {var} e boundary di parola)
    String evaluable = condition;
    for (final entry in variables.entries) {
      final key = entry.key;
      final value = entry.value;
      final valueStr = (value is bool) ? (value ? 'true' : 'false') : value.toString();
      evaluable = evaluable.replaceAll('{$key}', valueStr);
      evaluable = evaluable.replaceAllMapped(
        RegExp(r'\b' + RegExp.escape(key) + r'\b'),
        (m) => valueStr,
      );
    }

    // Sanifica: AND/OR/NOT, '=' -> '==' (preservando >=, <=, !=, ==), rimuovi ';'
    evaluable = _sanitizeCondition(evaluable);

    // Valuta con parser custom (supporta &&, ||, !, confronti, parentesi)
    final res = _evaluateConditionExpression(evaluable);
    if (res is bool) return res;
    if (res is num) return res != 0;
    throw Exception('Condizione non valida: $condition');
  }

  String _sanitizeCondition(String expression) {
    var s = expression.trim();
    if (s.endsWith(';')) s = s.substring(0, s.length - 1).trim();
    s = s.replaceAll(RegExp(r'\\bAND\\b', caseSensitive: false), '&&');
    s = s.replaceAll(RegExp(r'\\bOR\\b', caseSensitive: false), '||');
    s = s.replaceAll(RegExp(r'\\bNOT\\b', caseSensitive: false), '!');

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

    s = s.replaceAll(RegExp(r'\\s+'), ' ').trim();
    return s;
  }

  dynamic _evaluateConditionExpression(String expression) {
    var expr = expression.trim();

    // letterali
    if (expr.toLowerCase() == 'true') return true;
    if (expr.toLowerCase() == 'false') return false;
    final n = num.tryParse(expr);
    if (n != null) return n;

    expr = _stripOuterParentheses(expr);

    final orSplit = _splitAtTopLevel(expr, '||');
    if (orSplit != null) {
      final l = _evaluateConditionExpression(orSplit[0]);
      final r = _evaluateConditionExpression(orSplit[1]);
      final lb = (l is bool) ? l : (l != 0);
      final rb = (r is bool) ? r : (r != 0);
      return lb || rb;
    }

    final andSplit = _splitAtTopLevel(expr, '&&');
    if (andSplit != null) {
      final l = _evaluateConditionExpression(andSplit[0]);
      final r = _evaluateConditionExpression(andSplit[1]);
      final lb = (l is bool) ? l : (l != 0);
      final rb = (r is bool) ? r : (r != 0);
      return lb && rb;
    }

    if (expr.startsWith('!')) {
      final inner = _evaluateConditionExpression(expr.substring(1).trim());
      final ib = (inner is bool) ? inner : (inner != 0);
      return !ib;
    }

    for (final op in const ['>=', '<=', '==', '!=']) {
      final parts = _splitAtTopLevel(expr, op);
      if (parts != null) {
        final l = _evaluateConditionExpression(parts[0]);
        final r = _evaluateConditionExpression(parts[1]);
        switch (op) {
          case '>=':
            return (l is num && r is num && l >= r) ? 1 : 0;
          case '<=':
            return (l is num && r is num && l <= r) ? 1 : 0;
          case '==':
            return (l == r) ? 1 : 0;
          case '!=':
            return (l != r) ? 1 : 0;
        }
      }
    }

    for (final op in const ['>', '<']) {
      final parts = _splitAtTopLevel(expr, op);
      if (parts != null) {
        final l = _evaluateConditionExpression(parts[0]);
        final r = _evaluateConditionExpression(parts[1]);
        switch (op) {
          case '>':
            return (l is num && r is num && l > r) ? 1 : 0;
          case '<':
            return (l is num && r is num && l < r) ? 1 : 0;
        }
      }
    }

    // fallback: espressione aritmetica
    return _evaluateExpression(expr, {});
  }

  String _stripOuterParentheses(String s) {
    while (s.length >= 2 && s.startsWith('(') && s.endsWith(')')) {
      var depth = 0;
      var enclosesAll = true;
      for (int i = 0; i < s.length; i++) {
        final c = s[i];
        if (c == '(') depth++;
        if (c == ')') {
          depth--;
          if (depth == 0 && i != s.length - 1) { enclosesAll = false; break; }
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

  List<String>? _splitAtTopLevel(String s, String operator) {
    int depth = 0;
    for (int i = 0; i <= s.length - operator.length; i++) {
      final c = s[i];
      if (c == '(') depth++;
      else if (c == ')') { depth--; if (depth < 0) depth = 0; }
      if (depth == 0 && s.substring(i, i + operator.length) == operator) {
        final left = s.substring(0, i).trim();
        final right = s.substring(i + operator.length).trim();
        return [left, right];
      }
    }
    return null;
  }
}

/// 🎨 Custom Tab Button
class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final isHovering = states.isHovered;

        Color backgroundColor;
        Color foregroundColor;

        if (isSelected) {
          backgroundColor = theme.accentColor.defaultBrushFor(theme.brightness);
          foregroundColor = theme.brightness == Brightness.light
              ? Colors.white
              : Colors.black;
        } else if (isHovering) {
          backgroundColor = theme.resources.subtleFillColorSecondary;
          foregroundColor = theme.resources.textFillColorPrimary;
        } else {
          backgroundColor = Colors.transparent;
          foregroundColor = theme.resources.textFillColorSecondary;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, size: 14, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 🎨 Debug Expander
class _DebugExpander extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool initiallyExpanded;
  final Widget child;

  const _DebugExpander({
    required this.title,
    required this.icon,
    required this.initiallyExpanded,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Expander(
      initiallyExpanded: initiallyExpanded,
      header: Row(
        children: [
          FaIcon(
            icon,
            size: 14,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.typography.bodyStrong?.copyWith(
              fontSize: 14,
            ),
          ),
        ],
      ),
      content: child,
    );
  }
}

/// 🎨 Detail Row
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isNotEmpty ? value : '–',
              style: TextStyle(
                fontFamily: isCode ? 'monospace' : null,
                fontSize: 13,
                color: theme.resources.textFillColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 Variable Row with Copy
class _VariableRow extends StatelessWidget {
  final String name;
  final String value;

  const _VariableRow({
    required this.name,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accentColor
                  .defaultBrushFor(theme.brightness)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.accentColor.defaultBrushFor(theme.brightness),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.copy,
              size: 12,
              color: theme.resources.textFillColorSecondary,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
            },
          ),
        ],
      ),
    );
  }
}

/// 🎨 Execution Step
class _ExecutionStep extends StatelessWidget {
  final int index;
  final FlowNode node;
  final bool isCurrent;
  final bool isPast;

  const _ExecutionStep({
    required this.index,
    required this.node,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    IconData icon;
    Color iconColor;
    Color? backgroundColor;

    if (isCurrent) {
      icon = FontAwesomeIcons.locationDot;
      iconColor = theme.accentColor.defaultBrushFor(theme.brightness);
      backgroundColor = theme.accentColor
          .defaultBrushFor(theme.brightness)
          .withValues(alpha: 0.1);
    } else if (isPast) {
      icon = FontAwesomeIcons.circleCheck;
      iconColor = theme.resources.textFillColorSecondary;
      backgroundColor = null;
    } else {
      icon = FontAwesomeIcons.circle;
      iconColor = theme.resources.textFillColorTertiary;
      backgroundColor = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: isCurrent
            ? Border.all(
                color: theme.accentColor.defaultBrushFor(theme.brightness),
                width: 1.5)
            : null,
      ),
      child: ListTile(
        leading: FaIcon(icon, size: 16, color: iconColor),
        title: Text(
          node.text,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            color: isCurrent
                ? theme.resources.textFillColorPrimary
                : theme.resources.textFillColorSecondary,
          ),
        ),
        subtitle: Text(
          node.kind.name.toUpperCase(),
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 🛠️ Resolved Value - Risultato della risoluzione di un valore
class ResolvedValue {
  final dynamic value;
  final bool isLiteral;
  final String? error;

  ResolvedValue.success(this.value, {this.isLiteral = false}) : error = null;
  ResolvedValue.error(this.error) : value = null, isLiteral = false;
}
