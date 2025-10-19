import 'package:file_repository/file_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../blocs/debug_bloc/debug_bloc_exports.dart';
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

  const WorkArea({
    super.key,
    required this.repaintKey,
    required this.showGrid,
    required this.onToggleGrid,
    this.isReadOnly = false,
    this.allowDragInReadOnly = false,
  });

  @override
  State<WorkArea> createState() => _WorkAreaState();
}

class _WorkAreaState extends State<WorkArea>
    with SingleTickerProviderStateMixin {
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonAnimation;

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
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _buttonAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _buttonAnimationController.dispose();
    super.dispose();
  }

  String _renameInText(String text, String oldName, String newName) {
    if (text.isEmpty || oldName.isEmpty || oldName == newName) return text;
    final pattern = RegExp('\\b${RegExp.escape(oldName)}\\b');
    return text.replaceAll(pattern, newName);
  }

  /// Verifica se una variabile è utilizzata in qualsiasi nodo del flowchart
  bool _isVariableInUse(String variableName, List<FlowNode> nodes) {
    for (final node in nodes) {
      if (node is InputNode) {
        if (node.targetVariables.contains(variableName)) return true;
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
        isUsed = node.targetVariables.contains(variableName);
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
              targetVariables: node.targetVariables
                  .map((name) => name == oldName ? updatedVariable.name : name)
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

          if (!widget.isReadOnly)
            Positioned(
              top: 24,
              left: 24,
              child: ScaleTransition(
                scale: _buttonAnimation,
                child: FadeTransition(
                  opacity: _buttonAnimation,
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
                      );
                    },
                  ),
                ),
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
                  child: _InfoRulesButton(
                    onTap: () => AppDialogs.showInfoDialog(
                      context,
                      title: 'Regole',
                      message: 'Opzione regole da implementare',
                      type: DialogType.info,
                    ),
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

class _VariablesPanel extends StatelessWidget {
  final List<VariableDeclaration> variables;
  final Set<String> protectedVariableNames;
  final void Function(VariableScope) onAddVariable;
  final void Function(VariableDeclaration) onEditVariable;
  final void Function(VariableDeclaration) onDeleteVariable;

  const _VariablesPanel({
    required this.variables,
    required this.protectedVariableNames,
    required this.onAddVariable,
    required this.onEditVariable,
    required this.onDeleteVariable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final inputVars = variables.where((v) => v.scope == VariableScope.input).toList();
    final outputVars = variables.where((v) => v.scope == VariableScope.output).toList();
    final localVars = variables.where((v) => v.scope == VariableScope.local).toList();

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Text('Variabili',
                style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Divider(
            style: DividerThemeData(
              horizontalMargin: const EdgeInsets.symmetric(vertical: 8),
              thickness: 1,
              decoration: BoxDecoration(color: theme.resources.dividerStrokeColorDefault),
            ),
          ),
          _VariableCategory(
            title: 'Input',
            variables: inputVars,
            protectedVariableNames: protectedVariableNames,
            onAdd: () => onAddVariable(VariableScope.input),
            onEdit: onEditVariable,
            onDelete: onDeleteVariable,
          ),
          Divider(
            style: DividerThemeData(
              horizontalMargin: const EdgeInsets.symmetric(vertical: 8),
              thickness: 1,
              decoration: BoxDecoration(color: theme.resources.dividerStrokeColorDefault),
            ),
          ),
          _VariableCategory(
            title: 'Output',
            variables: outputVars,
            protectedVariableNames: protectedVariableNames,
            onAdd: () => onAddVariable(VariableScope.output),
            onEdit: onEditVariable,
            onDelete: onDeleteVariable,
          ),
          Divider(
            style: DividerThemeData(
              horizontalMargin: const EdgeInsets.symmetric(vertical: 8),
              thickness: 1,
              decoration: BoxDecoration(color: theme.resources.dividerStrokeColorDefault),
            ),
          ),
          _VariableCategory(
            title: 'Di Lavoro',
            variables: localVars,
            protectedVariableNames: protectedVariableNames,
            onAdd: () => onAddVariable(VariableScope.local),
            onEdit: onEditVariable,
            onDelete: onDeleteVariable,
          ),
        ],
      ),
    );
  }
}

class _VariableCategory extends StatelessWidget {
  final String title;
  final List<VariableDeclaration> variables;
  final Set<String> protectedVariableNames;
  final VoidCallback onAdd;
  final void Function(VariableDeclaration) onEdit;
  final void Function(VariableDeclaration) onDelete;

  const _VariableCategory({
    required this.title,
    required this.variables,
    required this.protectedVariableNames,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(title, style: theme.typography.bodyStrong?.copyWith(color: theme.resources.textFillColorSecondary)),
            ),
            Button(
              onPressed: onAdd,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
                shape: WidgetStateProperty.all(const CircleBorder()),
              ),
              child: const Icon(FluentIcons.add, size: 16),
            ),
          ],
        ),
        if (variables.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: variables
                  .map((variable) => _VariableDisplay(
                        variable: variable,
                        isProtected:
                            protectedVariableNames.contains(variable.name),
                        onEdit: () => onEdit(variable),
                        onDelete: () => onDelete(variable),
                      ))
                  .toList(),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
            child: Text('Nessuna', style: theme.typography.caption?.copyWith(fontStyle: FontStyle.italic)),
          ),
      ],
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

class _InfoRulesButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InfoRulesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Tooltip(
      message: 'Regole (coming soon)',
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
          icon: Icon(FontAwesomeIcons.listCheck, color: theme.accentColor, size: 25),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
      ),
    );
  }
}
