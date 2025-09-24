import 'package:flutter/material.dart';
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

  const WorkArea({
    super.key,
    required this.repaintKey,
    required this.showGrid,
    required this.onToggleGrid,
    this.isReadOnly = false,
  });

  @override
  State<WorkArea> createState() => _WorkAreaState();
}

class _WorkAreaState extends State<WorkArea> with SingleTickerProviderStateMixin {
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
        ),
        // Pulsanti mostrati solo se non read-only
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

  const _WorkAreaContent({required this.repaintKey, required this.showGrid, this.isReadOnly = false});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withAlpha(25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: FlowchartCanvas(showGrid: showGrid, isReadOnly: isReadOnly),
      ),
    );
  }
}

class _InfoRulesButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InfoRulesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Regole (coming soon)',
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          // mantiene stile coerente col toggle griglia
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withAlpha((0.15 * 255).round()),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: theme.dividerColor.withAlpha((0.1 * 255).round())),
        ),
        child: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
        ),
      ),
    );
  }
}
