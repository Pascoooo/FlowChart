import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../config/services/dialog_service/service_dialog.dart';
import 'flowchart_canvas.dart';
import 'grid_toggle.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';

/// The main work area for the flowchart editor, containing the canvas and UI elements.
class WorkArea extends StatefulWidget {
  final GlobalKey repaintKey;
  final bool showGrid;
  final VoidCallback onToggleGrid;
  final bool isReadOnly;
  final bool allowDragInReadOnly; // nuovo

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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _WorkAreaContent(
          repaintKey: widget.repaintKey,
          showGrid: widget.showGrid,
          isReadOnly: widget.isReadOnly,
          allowDragInReadOnly: widget.allowDragInReadOnly,
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

/// The content area of the work area, containing the flowchart canvas.
class _WorkAreaContent extends StatelessWidget {
  final GlobalKey repaintKey;
  final bool showGrid;
  final bool isReadOnly;
  final bool allowDragInReadOnly; // nuovo

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
class _InfoRulesButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InfoRulesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 1. Ottieni il tema di Fluent UI
    final theme = FluentTheme.of(context);

    // 2. Usa il Tooltip di Fluent UI
    return Tooltip(
      message: 'Regole (coming soon)',
      // 3. Usa un Container per replicare lo stile con bordo e ombra,
      //    proprio come nell'originale.
      child: Container(
        decoration: BoxDecoration(
          // Material `surface` -> Fluent `cardColor`
          color: theme.cardColor,
          // Il raggio del bordo rimane invariato
          borderRadius: BorderRadius.circular(16),
          // L'ombra viene tradotta direttamente.
          // Usiamo `Colors.black` con opacità per un'ombra generica.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          // Material `dividerColor` -> Usiamo un colore standard di Fluent per i bordi.
          border: Border.all(color: theme.resources.cardStrokeColorDefault),
        ),
        // 4. Usa l'IconButton di Fluent UI
        child: IconButton(
          onPressed: onTap,
          // Icona: `Icons.info_outline_rounded` -> `FluentIcons.info`
          // Colore: `Colors.blueAccent` -> `theme.accentColor` per adattarsi al tema
          icon: Icon(FontAwesomeIcons.listCheck, color: theme.accentColor, size:  25,),

          // CRUCIALE: Rendi trasparente lo sfondo dell'IconButton
          // per mostrare la decorazione del Container sottostante.
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
      ),
    );
  }
}