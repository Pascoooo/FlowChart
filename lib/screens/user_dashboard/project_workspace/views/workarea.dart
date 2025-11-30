/// Main work area for flowchart editing with canvas, toolbar, and variable management panel.
/// Orchestrates flowchart canvas, node palette, grid toggle, and read-only/debug mode controls.
/// Features animated variables panel and comprehensive variable validation.
import 'package:file_repository/file_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/debug_bloc/debug_bloc.dart';
import '../../../../blocs/debug_bloc/debug_state.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/dialog_service/service_dialog.dart';
import 'flowchart_canvas.dart';
import 'grid_toggle.dart';

class WorkArea extends StatefulWidget {
  final GlobalKey repaintKey;
  final bool showGrid;
  final VoidCallback onToggleGrid;
  final bool isReadOnly;
  final bool allowDragInReadOnly;
  final VoidCallback? onExport;
  final VoidCallback? onStartDebug;
  final VoidCallback? onLeave;

  const WorkArea({
    super.key,
    required this.repaintKey,
    required this.showGrid,
    required this.onToggleGrid,
    this.isReadOnly = false,
    this.allowDragInReadOnly = false,
    this.onExport,
    this.onStartDebug,
    this.onLeave,
  });

  @override
  State<WorkArea> createState() => _WorkAreaState();
}

class _WorkAreaState extends State<WorkArea>
    with TickerProviderStateMixin {
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonAnimation;
  late AnimationController _panelAnimationController;
  late Animation<Offset> _panelSlideAnimation;
  bool _isVariablesPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _buttonAnimation = CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeOutBack,
    );

    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _panelSlideAnimation =
        Tween<Offset>(begin: const Offset(-1.1, 0), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _panelAnimationController,
                curve: Curves.easeInOutCubic));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _buttonAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _buttonAnimationController.dispose();
    _panelAnimationController.dispose();
    super.dispose();
  }

  /// Toggles animated variables panel with slide transition.
  void _toggleVariablesPanel() {
    setState(() {
      _isVariablesPanelOpen = !_isVariablesPanelOpen;
      if (_isVariablesPanelOpen) {
        _panelAnimationController.forward();
      } else {
        _panelAnimationController.reverse();
      }
    });
  }

  /// Renames all occurrences of variable using word boundaries to avoid partial matches.
  String _renameInText(String text, String oldName, String newName) {
    if (text.isEmpty || oldName.isEmpty || oldName == newName) return text;
    final pattern = RegExp('\\b${RegExp.escape(oldName)}\\b');
    return text.replaceAll(pattern, newName);
  }

  /// Verifica se una variabile è utilizzata in qualsiasi nodo del flowchart
  bool _isVariableInUse(String variableName, List<FlowNode> nodes) {
    for (final node in nodes) {
      if (node is InputNode) {
        if (node.assignments.any((a) => a.target == variableName)) return true;
      } else if (node is OutputNode) {
        if (node.variables.any((v) => v.name == variableName)) return true;
      } else if (node is AssignmentNode) {
        if (node.assignments.any((a) => a.target == variableName || a.expression.contains(variableName))) return true;
      } else if (node is ProcessNode) {
        if (node.arguments.contains(variableName) || node.resultTarget == variableName) return true;
      } else if (node is DecisionNode) {
        // Controlla se la variabile è usata nelle clausole strutturate
        if (node.clauses.any((clause) =>
            clause.leftOperand == variableName ||
            (!clause.isRightLiteral && clause.rightOperand == variableName))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Restituisce una lista di nodi che utilizzano la variabile specificata
  List<String> _getNodesUsingVariable(String variableName, List<FlowNode> nodes) {
    final List<String> usingNodes = [];
    for (final node in nodes) {
      bool isUsed = false;
      if (node is InputNode) {
        isUsed = node.assignments.any((a) => a.target == variableName);
      } else if (node is OutputNode) {
        isUsed = node.variables.any((v) => v.name == variableName);
      } else if (node is AssignmentNode) {
        isUsed = node.assignments.any((a) => a.target == variableName || a.expression.contains(variableName));
      } else if (node is ProcessNode) {
        isUsed = node.arguments.contains(variableName) || node.resultTarget == variableName;
      } else if (node is DecisionNode) {
        // Controlla se la variabile è usata nelle clausole strutturate
        isUsed = node.clauses.any((clause) =>
            clause.leftOperand == variableName ||
            (!clause.isRightLiteral && clause.rightOperand == variableName));
      }
      if (isUsed) {
        usingNodes.add('${node.kind.name.toUpperCase()}: "${node.text}"');
      }
    }
    return usingNodes;
  }

  /// Gestisce l'aggiunta di una nuova variabile
  Future<void> _handleAddVariable(VariableScope scope) async {
    final flowchartBloc = context.read<FlowchartBloc>();
    final flowchartState = flowchartBloc.state;
    if (flowchartState is! FlowchartLoaded) return;

    final existingNames = flowchartState.flowchart.variables.map((v) => v.name).toSet();

    final newVariable = await AppDialogs.showAddVariableDialog(
      context: context,
      scope: scope,
      existingVariableNames: existingNames,
    );

    if (newVariable != null && mounted) {
      flowchartBloc.add(AddGlobalVariable(newVariable));
    }
  }

  /// Gestisce la modifica di una variabile esistente
  Future<void> _handleEditVariable(VariableDeclaration variableToEdit) async {
    final flowchartBloc = context.read<FlowchartBloc>();
    final flowchartState = flowchartBloc.state;
    if (flowchartState is! FlowchartLoaded) return;

    // Controlla se la variabile è usata in un DecisionNode (clausole strutturate)
    final isUsedInDecision = flowchartState.flowchart.nodes
        .whereType<DecisionNode>()
        .any((node) => node.clauses.any((clause) =>
            clause.leftOperand == variableToEdit.name ||
            (!clause.isRightLiteral && clause.rightOperand == variableToEdit.name)));

    final existingNames = flowchartState.flowchart.variables
        .where((v) => v.name != variableToEdit.name)
        .map((v) => v.name)
        .toSet();

    final dynamic result = await AppDialogs.showEditVariableDialog(
      context: context,
      variableToEdit: variableToEdit,
      existingVariableNames: existingNames,
      canEditType: !isUsedInDecision,
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      final updatedVariable = result['variable'] as VariableDeclaration;
      final oldName = result['oldName'] as String;

      // Se il nome è cambiato, propaga la modifica a tutti i nodi
      if (oldName != updatedVariable.name) {
        final newNodes = flowchartState.flowchart.nodes.map((node) {
          final updatedText = _renameInText(node.text, oldName, updatedVariable.name);

          if (node is InputNode) {
            return node.copyWith(
              text: updatedText,
              assignments: node.assignments
                  .map((a) => a.target == oldName
                      ? Assignment(target: updatedVariable.name, expression: a.expression)
                      : a)
                  .toList(),
            );
          } else if (node is OutputNode) {
            final updatedTemplate = _renameInText(node.template, oldName, updatedVariable.name);
            return node.copyWith(
              text: updatedText,
              template: updatedTemplate,
              variables: node.variables
                  .map((v) => v.name == oldName
                      ? VariableDeclaration(
                          name: updatedVariable.name,
                          dataType: v.dataType,
                          scope: v.scope,
                        )
                      : v)
                  .toList(),
            );
          } else if (node is AssignmentNode) {
            return node.copyWith(
              text: updatedText,
              assignments: node.assignments
                  .map((a) => Assignment(
                        target: a.target == oldName ? updatedVariable.name : a.target,
                        expression: a.expression.replaceAll(
                          RegExp('\\b${RegExp.escape(oldName)}\\b'),
                          updatedVariable.name,
                        ),
                      ))
                  .toList(),
            );
          } else if (node is ProcessNode) {
            return node.copyWith(
              text: updatedText,
              arguments: node.arguments
                  .map((arg) => arg == oldName ? updatedVariable.name : arg)
                  .toList(),
              resultTarget: node.resultTarget == oldName
                  ? updatedVariable.name
                  : node.resultTarget,
            );
          } else if (node is DecisionNode) {
            if (node.clauses.isEmpty) {
              // Nodo legacy: converti il testo aggiornato in clausole
              final parsedClauses = _parseClausesFromExpression(updatedText);
              if (parsedClauses.isNotEmpty) {
                // Determina il logicalJoin dal testo
                final newLogicalJoin = updatedText.contains(' OR ') ? 'OR' : 'AND';
                return node.copyWith(
                  text: updatedText,
                  clauses: parsedClauses,
                  logicalJoin: newLogicalJoin,
                );
              }
              // Se parsing fallisce, aggiorna solo l'etichetta
              return node.copyWith(text: updatedText);
            }
            return node.copyWith(
              text: updatedText,
              clauses: node.clauses.map((clause) {
                final newLeft = clause.leftOperand == oldName ? updatedVariable.name : clause.leftOperand;
                final newRight = !clause.isRightLiteral && clause.rightOperand == oldName
                    ? updatedVariable.name
                    : clause.rightOperand;
                return clause.copyWith(leftOperand: newLeft, rightOperand: newRight);
              }).toList(),
            );
          } else if (node is StartNode) {
            // StartNode.copyWith non supporta 'text': ricrea l'istanza
            return StartNode(
              id: node.id,
              x: node.x,
              y: node.y,
              width: node.width,
              height: node.height,
              text: updatedText,
              metadata: node.metadata,
            );
          } else if (node is EndNode) {
            // EndNode.copyWith non supporta 'text': ricrea l'istanza
            return EndNode(
              id: node.id,
              x: node.x,
              y: node.y,
              width: node.width,
              height: node.height,
              text: updatedText,
              metadata: node.metadata,
            );
          } else {
            // Nessuna modifica specifica: aggiorna solo l'etichetta se necessario
            return node; // evita copyWith dinamico non supportato
          }
        }).toList();

        final newVariablesList = flowchartState.flowchart.variables
            .map((v) => v.name == oldName ? updatedVariable : v)
            .toList();

        final newFlowchart = flowchartState.flowchart.copyWith(
          variables: newVariablesList,
          nodes: newNodes,
        );

        flowchartBloc.add(UpdateFlowchart(newFlowchart));
      } else {
        // Solo il tipo è cambiato, aggiorna solo la lista delle variabili
        final newVariablesList = flowchartState.flowchart.variables
            .map((v) => v.name == oldName ? updatedVariable : v)
            .toList();
        flowchartBloc.add(UpdateGlobalVariables(newVariablesList));
      }
    }
  }

  /// Gestisce l'eliminazione di una variabile
  Future<void> _handleDeleteVariable(VariableDeclaration variableToDelete) async {
    final flowchartBloc = context.read<FlowchartBloc>();
    final flowchartState = flowchartBloc.state;
    if (flowchartState is! FlowchartLoaded) return;

    // Verifica se la variabile è in uso
    if (_isVariableInUse(variableToDelete.name, flowchartState.flowchart.nodes)) {
      final usingNodes = _getNodesUsingVariable(variableToDelete.name, flowchartState.flowchart.nodes);
      final nodesList = usingNodes.join('\n• ');

      await AppDialogs.showInfoDialog(
        context,
        title: 'Impossibile Eliminare',
        message: 'La variabile "${variableToDelete.name}" è attualmente utilizzata nei seguenti nodi:\n\n• $nodesList\n\nRimuovi prima tutti i riferimenti a questa variabile per poterla eliminare.',
        type: DialogType.warning,
      );
      return;
    }

    final confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Conferma Eliminazione',
      message: 'Sei sicuro di voler eliminare la variabile "${variableToDelete.name}"?',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final newVariablesList = flowchartState.flowchart.variables
          .where((v) => v.name != variableToDelete.name)
          .toList();

      flowchartBloc.add(UpdateGlobalVariables(newVariablesList));
    }
  }

  // Parser semplice di espressioni booleane legacy in elenco di clausole
  List<ConditionClause> _parseClausesFromExpression(String text) {
    final clauses = <ConditionClause>[];
    if (text.trim().isEmpty) return clauses;

    // Spezza su AND/OR (il join sarà calcolato altrove)
    final parts = text.split(RegExp(r'\s+(?:AND|OR)\s+', caseSensitive: false));

    ConditionClause? parseSingle(String raw) {
      String t = raw.trim();
      // Rimuovi parentesi esterne
      while (t.startsWith('(') && t.endsWith(')')) {
        t = t.substring(1, t.length - 1).trim();
      }
      const ops = ['>=', '<=', '==', '!=', '>', '<', '='];
      String? op;
      for (final o in ops) {
        final idx = t.indexOf(' $o ');
        if (idx != -1) {
          op = o;
          break;
        }
      }
      if (op == null) return null;
      final split = t.split(' $op ');
      if (split.length != 2) return null;
      final left = split[0].trim();
      final right = split[1].trim();
      final normOp = (op == '=') ? '==' : op;

      bool isLiteral = false;
      if (right.isEmpty) {
        isLiteral = true;
      } else if ((right.startsWith("'") && right.endsWith("'")) ||
          (right.startsWith('"') && right.endsWith('"')) ||
          right.toLowerCase() == 'true' ||
          right.toLowerCase() == 'false' ||
          double.tryParse(right) != null) {
        isLiteral = true;
      }

      return ConditionClause(
        leftOperand: left,
        operator: normOp,
        rightOperand: right,
        isRightLiteral: isLiteral,
      );
    }

    for (final p in parts) {
      final c = parseSingle(p);
      if (c != null) clauses.add(c);
    }
    return clauses;
  }

  Future<void> _handleDeleteSelected(BuildContext context, FlowchartState flowchartState) async {
    if (flowchartState is! FlowchartLoaded) return;
    final selectedId = flowchartState.selectedNodeId;
    if (selectedId == null) return;

    final confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Elimina Nodo',
      message: 'Confermi di voler eliminare il nodo selezionato? L\'azione non è reversibile (se non con Annulla).',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      context.read<FlowchartBloc>().add(RemoveNode(selectedId));
    }
  }

  Future<void> _handleResetFlowchart(BuildContext context) async {
    final confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Reset Flowchart',
      message: 'Vuoi davvero resettare il flowchart? I nodi verranno rimossi mantenendo le variabili.',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      context.read<FlowchartBloc>().add(const ResetCanvasPreserveVariables());
    }
  }

  Future<void> _handleResetFromBlock(BuildContext context) async {
    final confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Reset da un blocco',
      message: 'Vuoi resettare il flowchart a partire da un blocco specifico?\nEntrerai in una modalità di selezione: scegli il blocco e poi conferma nell\'overlay.',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      context.read<FlowchartBloc>().add(const StartResetFromNodeSelection());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Avvolge il canvas con un listener sul FileSystemBloc per caricare il contenuto del file attivo
    return BlocListener<FileSystemBloc, FileSystemState>(
      listenWhen: (prev, curr) {
        // Ascolta SOLO il cambio dell'activeFileId, evita reload su salvataggi (lista file)
        if (prev is FileSystemLoaded && curr is FileSystemLoaded) {
          return prev.activeFileId != curr.activeFileId;
        }
        return curr is FileSystemLoaded;
      },
      listener: (context, state) {
        // NUOVO: Non ricaricare il flowchart mentre siamo in debug per evitare di perdere lo stato in memoria
        final dbg = context.read<DebugBloc>().state;
        final isInDebug = dbg is DebugInProgress || dbg is DebugAwaitingInput || dbg is DebugError || dbg is DebugCompleted;
        if (isInDebug) {
          return; // ignora aggiornamenti del filesystem durante il debug
        }

        if (state is FileSystemLoaded) {
          final activeId = state.activeFileId;
          if (activeId == null) return;
          final file = state.files.firstWhere(
            (f) => f.fileId == activeId,
            orElse: () => MyFile.empty,
          );
          if (file == MyFile.empty) return;

          // Carica il contenuto del file nel FlowchartBloc SOLO al cambio file
          context.read<FlowchartBloc>().add(
                LoadFlowchart(jsonContent: file.content, fileName: file.name, fileId: file.fileId)
              );
        }
      },
      child: Stack(
        children: [
          _WorkAreaContent(
            repaintKey: widget.repaintKey,
            showGrid: widget.showGrid,
            isReadOnly: widget.isReadOnly,
            allowDragInReadOnly: widget.allowDragInReadOnly,
          ),

          // Layer per i bottoni sopra la workarea
          if (!widget.isReadOnly && (widget.onExport != null || widget.onStartDebug != null || widget.onLeave != null))
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: BlocBuilder<FlowchartBloc, FlowchartState>(
                  builder: (context, flowchartState) {
                    final bool disableUI = flowchartState is FlowchartLoaded &&
                        flowchartState.isConnectorModeActive;

                    bool isPlayEnabled = widget.onStartDebug != null &&
                        flowchartState is FlowchartLoaded &&
                        !disableUI;
                    bool isResetEnabled = false;
                    bool isDeleteEnabled = false;
                    bool canUndo = false;
                    bool canRedo = false;

                    if (flowchartState is FlowchartLoaded) {
                      final nodes = flowchartState.flowchart.nodes;
                      final bool hasOnlyStartOrHeader = nodes.length == 1 &&
                          (nodes.first.kind == FlowNodeKind.start ||
                              nodes.first.kind ==
                                  FlowNodeKind.functionHeader);
                      isResetEnabled = !hasOnlyStartOrHeader && !disableUI;

                      final selectedId = flowchartState.selectedNodeId;
                      FlowNode? selectedNode = selectedId != null
                          ? flowchartState.getNodeById(selectedId)
                          : null;

                      if (selectedNode != null &&
                          selectedNode.kind != FlowNodeKind.start &&
                          selectedNode.kind !=
                              FlowNodeKind.functionHeader) {
                        if (selectedNode.kind == FlowNodeKind.doWhileLoop) {
                          final outs = flowchartState
                              .getOutgoingEdges(selectedNode.id);
                          final hasFalse =
                              outs.any((e) => e.port == 'false');
                          isDeleteEnabled = !hasFalse;
                        } else {
                          isDeleteEnabled = flowchartState
                              .getOutgoingEdges(selectedNode.id)
                              .isEmpty;
                        }
                      }
                      isDeleteEnabled = isDeleteEnabled && !disableUI;

                      canUndo =
                          context.read<FlowchartBloc>().canUndo && !disableUI;
                      canRedo =
                          context.read<FlowchartBloc>().canRedo && !disableUI;
                    }

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Bottoni centrali (undo, play, redo)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TopBarButton(
                              icon: Icons.undo_rounded,
                              tooltip: 'Annulla',
                              enabled: canUndo,
                              onTap: canUndo
                                  ? () => context
                                      .read<FlowchartBloc>()
                                      .add(const Undo())
                                  : null,
                              iconSize: 22,
                            ),
                            if (widget.onStartDebug != null) ...[
                              const SizedBox(width: 12),
                              _TopBarButton(
                                icon: FontAwesomeIcons.play,
                                tooltip: 'Avvia debug',
                                enabled: isPlayEnabled,
                                onTap: isPlayEnabled ? widget.onStartDebug : null,
                                isAccent: true,
                              ),
                            ],
                            const SizedBox(width: 12),
                            _TopBarButton(
                              icon: Icons.redo_rounded,
                              tooltip: 'Ripeti',
                              enabled: canRedo,
                              onTap: canRedo
                                  ? () => context
                                      .read<FlowchartBloc>()
                                      .add(const Redo())
                                  : null,
                              iconSize: 22,
                            ),
                          ],
                        ),

                        // Bottoni laterali (sinistra e destra)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Bottoni di gestione flowchart (sinistra)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _TopBarButton(
                                  icon: FontAwesomeIcons.trash,
                                  tooltip: 'Elimina nodo selezionato',
                                  enabled: isDeleteEnabled,
                                  onTap: isDeleteEnabled
                                      ? () => _handleDeleteSelected(
                                          context, flowchartState)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                _TopBarButton(
                                  icon: FontAwesomeIcons.arrowRotateLeft,
                                  tooltip: 'Resetta flowchart',
                                  enabled: isResetEnabled,
                                  onTap: isResetEnabled
                                      ? () => _handleResetFlowchart(context)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                _TopBarButton(
                                  icon: FontAwesomeIcons.scissors,
                                  tooltip: 'Resetta da un blocco',
                                  enabled: isResetEnabled,
                                  onTap: isResetEnabled
                                      ? () => _handleResetFromBlock(context)
                                      : null,
                                ),
                              ],
                            ),

                            // Bottoni a destra (export, edit)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                _TopBarButton(
                                  icon: FontAwesomeIcons.download,
                                  tooltip: 'Esporta immagine',
                                  enabled: !disableUI,
                                  onTap: !disableUI ? widget.onExport : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // ✨ NUOVO PANNELLO VARIABILI LATERALE E CORTO
          if (!widget.isReadOnly)
            SlideTransition(
              position: _panelSlideAnimation,
              child: BlocBuilder<FlowchartBloc, FlowchartState>(
                builder: (context, state) {
                  final variables = (state is FlowchartLoaded)
                      ? state.flowchart.variables
                      : <VariableDeclaration>[];

                  final protectedVariableNames = (state is FlowchartLoaded)
                      ? state.flowchart.signature.parameters
                          .map((p) => p.name)
                          .toSet()
                      : <String>{};

                  return _VariablesPanel(
                    variables: variables,
                    protectedVariableNames: protectedVariableNames,
                    onAddVariable: _handleAddVariable,
                    onEditVariable: _handleEditVariable,
                    onDeleteVariable: _handleDeleteVariable,
                    onClose: _toggleVariablesPanel,
                  );
                },
              ),
            ),

          if (!widget.isReadOnly) ...[
            Positioned(
              bottom: 24,
              left: 24,
              child: ScaleTransition(
                scale: _buttonAnimation,
                child: FadeTransition(
                  opacity: _buttonAnimation,
                  child: _VariablesPanelButton(
                    onTap: _toggleVariablesPanel,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: ScaleTransition(
                scale: _buttonAnimation,
                child: FadeTransition(
                  opacity: _buttonAnimation,
                  child: GridToggleButton(
                    showGrid: widget.showGrid,
                    onToggle: widget.onToggleGrid,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkAreaContent extends StatelessWidget {
  final GlobalKey repaintKey;
  final bool showGrid;
  final bool isReadOnly;
  final bool allowDragInReadOnly;

  const _WorkAreaContent(
      {required this.repaintKey, required this.showGrid, this.isReadOnly = false, this.allowDragInReadOnly = false});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: FlowchartCanvas(showGrid: showGrid, isReadOnly: isReadOnly, allowDragInReadOnly: allowDragInReadOnly),
      ),
    );
  }
}

class _VariablesPanelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _VariablesPanelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Tooltip(
      message: 'Gestisci Variabili',
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: theme.resources.cardStrokeColorDefault),
        ),
        child: IconButton(
          onPressed: onTap,
          icon: SvgPicture.asset(
            'assets/icons/var.svg',
            colorFilter: ColorFilter.mode(
              theme.accentColor, // Applica il colore blu del tema
              BlendMode.srcIn,
            ),
            width: 25, // Imposta la larghezza
            height: 25, // Imposta l'altezza
          ),
        ),
      ),
    );
  }
}

class _VariablesPanel extends StatefulWidget {
  final List<VariableDeclaration> variables;
  final Set<String> protectedVariableNames;
  final void Function(VariableScope) onAddVariable;
  final void Function(VariableDeclaration) onEditVariable;
  final void Function(VariableDeclaration) onDeleteVariable;
  final VoidCallback onClose;

  const _VariablesPanel({
    required this.variables,
    required this.protectedVariableNames,
    required this.onAddVariable,
    required this.onEditVariable,
    required this.onDeleteVariable,
    required this.onClose,
  });

  @override
  State<_VariablesPanel> createState() => _VariablesPanelState();
}

class _VariablesPanelState extends State<_VariablesPanel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final inputs =
    widget.variables.where((v) => v.scope == VariableScope.input).toList();
    final outputs =
    widget.variables.where((v) => v.scope == VariableScope.output).toList();
    final works =
    widget.variables.where((v) => v.scope == VariableScope.local).toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: 320,
          height: 550,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.resources.cardStrokeColorDefault),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 12,
                  offset: Offset(4, 0)),
            ],
          ),
          // È necessario un Column per contenere sia l'Header che l'Expanded
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Gestione Variabili',
                          style: theme.typography.subtitle),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.chrome_close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // Corpo (TabView)
              Expanded(
                child: TabView(
                  currentIndex: _currentIndex,
                  onChanged: (index) => setState(() => _currentIndex = index),
                  tabs: [
                    Tab(
                      text: const Text('Input'),
                      body: _VariableList(
                        scope: VariableScope.input,
                        variables: inputs,
                        protectedVariableNames: widget.protectedVariableNames,
                        onAdd: () => widget.onAddVariable(VariableScope.input),
                        onEdit: widget.onEditVariable,
                        onDelete: widget.onDeleteVariable,
                      ),
                    ),
                    Tab(
                      text: const Text('Output'),
                      body: _VariableList(
                          scope: VariableScope.output,
                          variables: outputs,
                          protectedVariableNames: widget.protectedVariableNames,
                          onAdd: () => widget.onAddVariable(VariableScope.output),
                          onEdit: widget.onEditVariable,
                          onDelete: widget.onDeleteVariable,
                      ),
                    ),
                    Tab(
                      text: const Text('Lavoro'),
                      body: _VariableList(
                        scope: VariableScope.local,
                        variables: works,
                        protectedVariableNames: widget.protectedVariableNames,
                        onAdd: () => widget.onAddVariable(VariableScope.local),
                        onEdit: widget.onEditVariable,
                        onDelete: widget.onDeleteVariable,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariableList extends StatelessWidget {
  final VariableScope scope;
  final List<VariableDeclaration> variables;
  final Set<String> protectedVariableNames;
  final VoidCallback onAdd;
  final void Function(VariableDeclaration) onEdit;
  final void Function(VariableDeclaration) onDelete;

  const _VariableList({
    required this.scope,
    required this.variables,
    required this.protectedVariableNames,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: FilledButton(
          onPressed: onAdd,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FluentIcons.add, size: 16),
              const SizedBox(width: 8),
              Text('Aggiungi Variabile ${scope.name}'),
            ],
          ),
        ),
      ),
      content: variables.isEmpty
          ? Center(child: Text('Nessuna variabile', style: theme.typography.caption))
          : ListView.separated(
              padding: const EdgeInsets.all(12.0),
              itemCount: variables.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final v = variables[i];
                return _VariableDisplay(
                  variable: v,
                  isProtected: protectedVariableNames.contains(v.name),
                  onEdit: () => onEdit(v),
                  onDelete: () => onDelete(v),
                );
              },
            ),
    );
  }
}

class _VariableDisplay extends StatelessWidget {
  final VariableDeclaration variable;
  final bool isProtected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VariableDisplay({
    required this.variable,
    required this.isProtected,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final flyoutController = FlyoutController();

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          if (isProtected)
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Icon(FluentIcons.lock,
                  size: 12, color: theme.resources.textFillColorSecondary),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              variable.dataType,
              style: theme.typography.caption
                  ?.copyWith(fontWeight: FontWeight.w600, color: theme.accentColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(variable.name,
                style: theme.typography.body, overflow: TextOverflow.ellipsis),
          ),
          FlyoutTarget(
            controller: flyoutController,
            child: IconButton(
              icon: const Icon(FluentIcons.more_vertical, size: 14),
              onPressed: () {
                flyoutController.showFlyout(
                  placementMode: FlyoutPlacementMode.bottomRight,
                  builder: (flyoutContext) {
                    return MenuFlyout(
                      items: [
                        MenuFlyoutItem(
                          leading: const Icon(FluentIcons.edit),
                          text: const Text('Modifica'),
                          onPressed: isProtected
                              ? null
                              : () {
                                  Navigator.pop(flyoutContext);
                                  onEdit();
                                },
                        ),
                        MenuFlyoutItem(
                          leading: Icon(FluentIcons.delete, color: Colors.red),
                          text: Text('Elimina',
                              style: TextStyle(color: Colors.red)),
                          onPressed: isProtected
                              ? null
                              : () {
                                  Navigator.pop(flyoutContext);
                                  onDelete();
                                },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    if (isProtected) {
      return Tooltip(
        message:
            'Questa variabile è un parametro della funzione e non può essere modificata o eliminata.',
        child: content,
      );
    }

    return content;
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onTap;
  final bool isAccent;
  final double? iconSize;
  final Color? color; // Colore personalizzato per icona/bordo

  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    this.isAccent = false,
    this.iconSize,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color ?? (isAccent && enabled
                  ? theme.accentColor
                  : theme.resources.cardStrokeColorDefault),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              icon,
              size: iconSize ?? 18,
              color: color ?? (isAccent && enabled ? theme.accentColor : null),
            ),
            onPressed: enabled ? onTap : null,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
              padding: WidgetStateProperty.all(const EdgeInsets.all(8)),
            ),
          ),
        ),
      ),
    );
  }
}

