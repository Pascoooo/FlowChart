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
import '../../../../config/services/dialog_service.dart';

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
  static const double interactionAreaSize = 300.0;
  static const int _panelOptionsCount = 5; // Input, Output, Processo, Condizione, Fine
  double get _estimatedPanelHeight => _panelOptionsCount * 48.0 + (_panelOptionsCount - 1) * 1.0 + 8; // button + dividers + small padding

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

    // Parametri pannello
    const double panelWidth = 180; // larghezza effettiva pannello
    final double panelHeight = _estimatedPanelHeight; // ~252px
    const double gap = 6.0; // distanza tra bottone e pannello

    // Calcolo posizione globale preferita (sotto)
    double panelTopGlobal = handleCenter.dy + handleSize / 2 + gap;
    final bool canShowBelow = panelTopGlobal + panelHeight <= widget.canvasConstraints.maxHeight - 4;
    final bool opensBelow = canShowBelow;
    if (!canShowBelow) {
      panelTopGlobal = handleCenter.dy - handleSize / 2 - gap - panelHeight; // sopra
      if (panelTopGlobal < 4) panelTopGlobal = 4;
    }

    // Posizionamento orizzontale centrato sul bottone
    double panelLeftGlobal = handleCenter.dx - panelWidth / 2;
    if (panelLeftGlobal < 4) panelLeftGlobal = 4;
    final maxLeft = widget.canvasConstraints.maxWidth - panelWidth - 4;
    if (panelLeftGlobal > maxLeft) panelLeftGlobal = maxLeft;

    // Area interattiva FISSA (niente più calcoli dinamici variabili):
    // - Chiusa: piccola (300x300) per non bloccare tap esterni
    // - Aperta: dimensione fissa maggiore (400x560) per includere sempre tutto il pannello
    final double areaWidth = _showPanel ? 400 : interactionAreaSize; // 400 > 180 + margine
    final double areaHeight = _showPanel ? 560 : interactionAreaSize; // 560 >= 2*(panelHeight + handle/2 + gap)

    // Centra l'area rispetto all'handle
    double areaLeft = handleCenter.dx - areaWidth / 2;
    double areaTop = handleCenter.dy - areaHeight / 2;

    // Clamp ai bordi canvas
    if (areaLeft < 0) areaLeft = 0;
    if (areaTop < 0) areaTop = 0;
    if (areaLeft + areaWidth > widget.canvasConstraints.maxWidth) {
      areaLeft = widget.canvasConstraints.maxWidth - areaWidth;
    }
    if (areaTop + areaHeight > widget.canvasConstraints.maxHeight) {
      areaTop = widget.canvasConstraints.maxHeight - areaHeight;
    }

    // Converte posizione pannello in coordinate relative all'area
    final panelLeftRelative = panelLeftGlobal - areaLeft;
    final panelTopRelative = panelTopGlobal - areaTop;

    return Positioned(
      left: areaLeft,
      top: areaTop,
      child: SizedBox(
        width: areaWidth,
        height: areaHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_showPanel)
              Positioned(
                left: panelLeftRelative,
                top: panelTopRelative,
                child: FadeTransition(
                  opacity: _panelAnimation,
                  child: ScaleTransition(
                    scale: _panelAnimation,
                    alignment: opensBelow ? Alignment.topCenter : Alignment.bottomCenter,
                    child: ShapeCreationPanel(
                      onShapeCreated: _closePanel,
                      sourceShapeId: widget.sourceShape.id,
                      canvasConstraints: widget.canvasConstraints,
                      fromPort: _resolvePort(),
                    ),
                  ),
                ),
              ),
            // Bottone handle (rimane centrato rispetto all'area calcolata)
            Positioned(
              left: handleCenter.dx - areaLeft - handleSize / 2,
              top: handleCenter.dy - areaTop - handleSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
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
    const gap = 5.0; // distanza dalla forma
    switch (widget.direction) {
      case HandleDirection.bottom:
        return Offset(shape.x + shape.width / 2, shape.y + shape.height + gap + (handleSize / 2));
      case HandleDirection.top:
        return Offset(shape.x + shape.width / 2, shape.y - gap - (handleSize / 2));
      case HandleDirection.left:
        return Offset(shape.x - gap - (handleSize / 2), shape.y + shape.height / 2);
      case HandleDirection.right:
        return Offset(shape.x + shape.width + gap + (handleSize / 2), shape.y + shape.height / 2);
    }
  }

  String? _resolvePort() {
    if (widget.sourceShape.type == 'condizione') {
      switch (widget.direction) {
        case HandleDirection.left:
          return 'false';
        case HandleDirection.right:
          return 'true';
        default:
          return null;
      }
    }
    return null;
  }
}

class ShapeCreationPanel extends StatelessWidget {
  final String sourceShapeId;
  final VoidCallback onShapeCreated;
  final BoxConstraints canvasConstraints;
  final String? fromPort;

  const ShapeCreationPanel({
    super.key,
    required this.sourceShapeId,
    required this.onShapeCreated,
    required this.canvasConstraints,
    this.fromPort,
  });

  /// Invia l'evento semplificato al BLoC.
  /// Non crea più la forma, ma dice al BLoC QUALE TIPO di forma creare.
  void _createShape(BuildContext context, ShapeType shapeType) async {
    final bloc = context.read<FlowchartBloc>();
    final flowState = bloc.state;

    // Caso speciale: utente richiede una seconda 'Fine'
    if (shapeType == ShapeType.fine && flowState is FlowchartLoaded) {
      final alreadyEnd = flowState.shapes.any((s) => s.type == 'fine' || s.type == 'end');
      if (alreadyEnd) {
        final bool? confirmed = await DialogService.showConfirmationDialog(
          context,
          title: 'Collegare al nodo Fine esistente? ',
          message: 'Esiste già un nodo Fine. Vuoi collegarti a quest\' ultimo?',
          confirmText: 'Collega',
          cancelText: 'Annulla',
        );
        if (confirmed == true) {
          bloc.add(LinkToExistingEnd(fromShapeId: sourceShapeId, fromPort: fromPort));
          onShapeCreated();
        } else {
          onShapeCreated();
        }
        return;
      }
    }

    bloc.add(AddShape(
      shapeType: shapeType,
      fromShapeId: sourceShapeId,
      fromPort: fromPort,
      canvasConstraints: canvasConstraints,
    ));

    onShapeCreated();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: 180, // leggermente più larga per testi
          decoration: BoxDecoration(
            // pannello torna neutro (surface leggermente traslucido) invece del colore del testo
            color: theme.colorScheme.surface.withAlpha((0.92 * 255).round()),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(
              color: theme.colorScheme.onSurface.withAlpha((0.08 * 255).round()),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShapeButton(
                icon: FontAwesomeIcons.download, // Input
                label: 'Input',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createShape(context, ShapeType.input),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.upload, // Output
                label: 'Output',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createShape(context, ShapeType.output),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.gear, // Processo
                label: 'Processo',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createShape(context, ShapeType.processo),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.codeBranch, // Condizione / diramazione
                label: 'Condizione',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createShape(context, ShapeType.condizione),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.flagCheckered, // Fine
                label: 'Fine',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createShape(context, ShapeType.fine),
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
  final Color? textColor;

  const ShapeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLast = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = textColor ?? CupertinoColors.activeBlue;
    return CupertinoButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      pressedOpacity: 0.85,
      alignment: Alignment.centerLeft,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(14.0))
          : BorderRadius.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
          Icon(icon, size: 20, color: effectiveColor),
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
