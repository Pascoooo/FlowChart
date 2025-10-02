import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
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

  final void Function(VariableScope)? onAddVariable;
  final void Function(VariableDeclaration)? onEditVariable;
  final void Function(VariableDeclaration)? onDeleteVariable;

  const WorkArea({
    super.key,
    required this.repaintKey,
    required this.showGrid,
    required this.onToggleGrid,
    this.onAddVariable,
    this.onEditVariable,
    this.onDeleteVariable,
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

  @override
  Widget build(BuildContext context) {
    final bool canManageVariables = widget.onAddVariable != null &&
        widget.onEditVariable != null &&
        widget.onDeleteVariable != null;

    return Stack(
      children: [
        _WorkAreaContent(
          repaintKey: widget.repaintKey,
          showGrid: widget.showGrid,
          isReadOnly: widget.isReadOnly,
          allowDragInReadOnly: widget.allowDragInReadOnly,
        ),

        if (!widget.isReadOnly && canManageVariables)
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

                    return _VariablesPanel(
                      variables: variables,
                      onAddVariable: widget.onAddVariable!,
                      onEditVariable: widget.onEditVariable!,
                      onDeleteVariable: widget.onDeleteVariable!,
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
              color: Colors.black.withOpacity(0.08),
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
  final void Function(VariableScope) onAddVariable;
  final void Function(VariableDeclaration) onEditVariable;
  final void Function(VariableDeclaration) onDeleteVariable;

  const _VariablesPanel({
    required this.variables,
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
      width: 220,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text('Variabili', style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.w600)),
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
  final VoidCallback onAdd;
  final void Function(VariableDeclaration) onEdit;
  final void Function(VariableDeclaration) onDelete;

  const _VariableCategory({
    required this.title,
    required this.variables,
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
              children: variables.map((variable) => _VariableDisplay(
                variable: variable,
                onEdit: () => onEdit(variable),
                onDelete: () => onDelete(variable),
              )).toList(),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VariableDisplay({
    required this.variable,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final flyoutController = FlyoutController();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              variable.dataType,
              style: theme.typography.caption?.copyWith(fontWeight: FontWeight.w600, color: theme.accentColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(variable.name, style: theme.typography.body, overflow: TextOverflow.ellipsis),
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
                          onPressed: () {
                            Navigator.pop(flyoutContext);
                            onEdit();
                          },
                        ),
                        MenuFlyoutItem(
                          leading: Icon(FluentIcons.delete, color: Colors.red),
                          text: Text('Elimina', style: TextStyle(color: Colors.red)),
                          onPressed: () {
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
              color: Colors.black.withOpacity(0.15),
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