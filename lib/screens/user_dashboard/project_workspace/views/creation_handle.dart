import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/flowchart_bloc/FlowchartShapeFactory.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import 'flowchart_canvas.dart';

class CreationHandle extends StatefulWidget {
  final HandleDirection direction;
  final FlowchartShape sourceShape;
  final ValueChanged<HandleDirection?> onPanelToggled;
  final BoxConstraints canvasConstraints;

  const CreationHandle({
    required Key key,
    required this.direction,
    required this.sourceShape,
    required this.onPanelToggled,
    required this.canvasConstraints,
  }) : super(key: key);

  @override
  State<CreationHandle> createState() => _CreationHandleState();
}

class _CreationHandleState extends State<CreationHandle>
    with SingleTickerProviderStateMixin {
  bool _showPanel = false;
  late AnimationController _panelAnimationController;
  late Animation<double> _panelAnimation;

  static const double handleSize = 24.0;
  static const double panelHeight = 150.0;
  static const double interactionAreaSize = 300.0;

  @override
  void initState() {
    super.initState();
    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _panelAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handleCenter = _getHandleCenter();
    final areaTopLeft = Offset(
      handleCenter.dx - (interactionAreaSize / 2),
      handleCenter.dy - (interactionAreaSize / 2),
    );

    return Positioned(
      left: areaTopLeft.dx,
      top: areaTopLeft.dy,
      child: SizedBox(
        width: interactionAreaSize,
        height: interactionAreaSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_showPanel)
              Positioned.fill(
                child: Align(
                  alignment: _getPanelAlignment(),
                  child: FadeTransition(
                    opacity: _panelAnimation,
                    child: ScaleTransition(
                      scale: _panelAnimation,
                      alignment: _getPanelAlignment(),
                      child: ShapeCreationPanel(
                        onShapeCreated: _closePanel,
                        sourceShapeId: widget.sourceShape.id,
                        canvasConstraints: widget.canvasConstraints,
                      ),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showPanel = !_showPanel;
                  widget.onPanelToggled(_showPanel ? widget.direction : null);
                  if (_showPanel) {
                    _panelAnimationController.forward();
                  } else {
                    _panelAnimationController.reverse();
                  }
                });
              },
              child: Container(
                width: handleSize,
                height: handleSize,
                decoration: BoxDecoration(
                  color: _showPanel
                      ? CupertinoColors.systemGrey
                      : Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    _showPanel ? Icons.remove : Icons.add,
                    key: ValueKey<bool>(_showPanel),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closePanel() {
    setState(() {
      _showPanel = false;
      widget.onPanelToggled(null);
      _panelAnimationController.reverse();
    });
  }

  Offset _getHandleCenter() {
    final shape = widget.sourceShape;
    // La logica è semplificata perché abbiamo solo il pulsante inferiore
    return Offset(shape.x + shape.width / 2, shape.y + shape.height + 5 + (handleSize / 2));
  }

  Alignment _getPanelAlignment() {
    final handleCenter = _getHandleCenter();
    // Calcola dove finirebbe il bordo inferiore del pannello
    final panelBottomEdge = handleCenter.dy + (handleSize / 2) + 18 + panelHeight;
    // Controlla se sfora l'altezza massima della canvas
    final bool goesBeyondCanvas = panelBottomEdge > widget.canvasConstraints.maxHeight;

    const double spacing = 1.3;

    // Se sfora, apri verso l'alto (spacing negativo), altrimenti verso il basso (spacing positivo)
    return Alignment(0, goesBeyondCanvas ? -spacing : spacing);
  }
}

class ShapeCreationPanel extends StatelessWidget {
  final String sourceShapeId;
  final VoidCallback onShapeCreated;
  final BoxConstraints canvasConstraints;

  const ShapeCreationPanel({
    super.key,
    required this.sourceShapeId,
    required this.onShapeCreated,
    required this.canvasConstraints,
  });

  /// Invia l'evento semplificato al BLoC.
  /// Non crea più la forma, ma dice al BLoC QUALE TIPO di forma creare.
  void _createShape(BuildContext context, ShapeType shapeType) {
    final bloc = context.read<FlowchartBloc>();

    // CORREZIONE: Passa correttamente il parametro shapeType all'evento AddShape
    bloc.add(AddShape(
      shapeType: shapeType,
      fromShapeId: sourceShapeId,
      canvasConstraints: canvasConstraints,
    ));

    onShapeCreated();
  }
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.withOpacity(0.8),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(
              color: CupertinoColors.systemGrey4.withOpacity(0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShapeButton(
                icon: CupertinoIcons.square_on_square,
                label: 'Processo',
                onPressed: () => _createShape(context, ShapeType.process),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.font,
                label: 'Decisione',
                onPressed: () => _createShape(context, ShapeType.decision),
              ),
              const _Divider(),
              ShapeButton(
                icon: CupertinoIcons.circle,
                label: 'Fine',
                isLast: true,
                onPressed: () => _createShape(context, ShapeType.end),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShapeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLast;

  const ShapeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(14.0))
          : BorderRadius.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.activeBlue,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: '.SF Pro Text',
              letterSpacing: -0.2,
            ),
          ),
          Icon(icon, size: 22, color: CupertinoColors.activeBlue),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: CupertinoColors.systemGrey4.withOpacity(0.5),
    );
  }
}