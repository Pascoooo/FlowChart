import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/dialog_service/service_dialog.dart';
import 'flowchart_canvas.dart';
import 'grid_toggle.dart';

/// The main work area for the flowchart editor, containing the canvas and UI elements.
class WorkArea extends StatefulWidget {
  final GlobalKey repaintKey;
  final bool showGrid;
  final VoidCallback onToggleGrid;
  final bool isReadOnly;
  final bool allowDragInReadOnly;

  // FIX: Rese le callback opzionali per permettere l'uso del widget in contesti di sola lettura.
  final VoidCallback? onAddInputVariable;
  final VoidCallback? onAddOutputVariable;
  final VoidCallback? onAddLocalVariable;

  const WorkArea({
    super.key,
    required this.repaintKey,
    required this.showGrid,
    required this.onToggleGrid,
    this.onAddInputVariable,
    this.onAddOutputVariable,
    this.onAddLocalVariable,
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
    // FIX: Verifica se le callback sono state fornite per decidere se mostrare il pannello.
    final bool canAddVariables = widget.onAddInputVariable != null &&
        widget.onAddOutputVariable != null &&
        widget.onAddLocalVariable != null;

    return Stack(
      children: [
        _WorkAreaContent(
          repaintKey: widget.repaintKey,
          showGrid: widget.showGrid,
          isReadOnly: widget.isReadOnly,
          allowDragInReadOnly: widget.allowDragInReadOnly,
        ),

        // Mostra il pannello solo se le callback sono disponibili e non è in sola lettura.
        if (!widget.isReadOnly && canAddVariables)
          Positioned(
            top: 24,
            left: 24,
            child: ScaleTransition(
              scale: _buttonAnimation,
              child: FadeTransition(
                opacity: _buttonAnimation,
                child: _VariablesPanel(
                  onAddInput: widget.onAddInputVariable!,
                  onAddOutput: widget.onAddOutputVariable!,
                  onAddLocal: widget.onAddLocalVariable!,
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
    return RepaintBoundary
      (
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
  final VoidCallback onAddInput;
  final VoidCallback onAddOutput;
  final VoidCallback onAddLocal;

  const _VariablesPanel({
    required this.onAddInput,
    required this.onAddOutput,
    required this.onAddLocal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              'Variabili',
              style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Divider(
            style: DividerThemeData(
              horizontalMargin: const EdgeInsets.symmetric(vertical: 8),
              thickness: 1,
              decoration: BoxDecoration(color: theme.resources.dividerStrokeColorDefault),
            ),
          ),
          _VariableCategory(title: 'Input', onAdd: onAddInput),
          Divider(
            style: DividerThemeData(
              horizontalMargin: const EdgeInsets.symmetric(vertical: 8),
              thickness: 1,
              decoration: BoxDecoration(color: theme.resources.dividerStrokeColorDefault),
            ),
          ),
          _VariableCategory(title: 'Output', onAdd: onAddOutput),
          Divider(
            style: DividerThemeData(
              horizontalMargin: const EdgeInsets.symmetric(vertical: 8),
              thickness: 1,
              decoration: BoxDecoration(color: theme.resources.dividerStrokeColorDefault),
            ),
          ),
          _VariableCategory(title: 'Di Lavoro', onAdd: onAddLocal),
        ],
      ),
    );
  }
}

class _VariableCategory extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _VariableCategory({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            title,
            style: theme.typography.bodyStrong?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
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
          icon: Icon(FontAwesomeIcons.listCheck, color: theme.accentColor, size:  25,),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
      ),
    );
  }
}