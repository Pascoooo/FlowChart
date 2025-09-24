import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:file_repository/file_repository.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';

import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';

enum HandleDirection { top, right, bottom, left }

class CreationHandle extends StatefulWidget {
  final HandleDirection direction;
  final FlowNode sourceNode;
  final ValueChanged<bool> onPanelToggled;
  final BoxConstraints canvasConstraints;

  const CreationHandle({
    required Key key,
    required this.direction,
    required this.sourceNode,
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
  static const double _buttonHeight = 44.0; // altezza più compatta per ogni voce
  static const double panelHeight = (_buttonHeight * 5) + (4 * 1.0); // 5 bottoni + 4 divisori (linee da 1px)
  static const double panelWidth = 180.0;
  static const double panelGap = 12.0;

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

  void _togglePanel() {
    setState(() {
      _showPanel = !_showPanel;
      widget.onPanelToggled(_showPanel);
      if (_showPanel) {
        _panelAnimationController.forward();
      } else {
        _panelAnimationController.reverse();
      }
    });
  }

  void _closePanel() {
    if (_showPanel) {
      _togglePanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final handleCenter = _getHandleCenter();

    // --- NUOVA LOGICA DI LAYOUT ---

    // 1. Determina se il pannello deve aprirsi verso l'alto
    final spaceBelow = widget.canvasConstraints.maxHeight - (handleCenter.dy + handleSize / 2 + panelGap);
    final opensUpwards = spaceBelow < panelHeight && widget.direction == HandleDirection.bottom;

    // 2. Calcola la dimensione e la posizione di un'area di interazione che contenga
    //    sia l'handle che il pannello, per garantire che tutto sia cliccabile.
    final double areaWidth = panelWidth;
    final double areaHeight = panelHeight + handleSize + panelGap;

    double areaLeft = handleCenter.dx - (areaWidth / 2);
    double areaTop = opensUpwards
        ? handleCenter.dy + handleSize / 2 - areaHeight
        : handleCenter.dy - handleSize / 2;

    // 3. Calcola le posizioni RELATIVE dell'handle e del pannello dentro questa area
    final double handleTopRelative = opensUpwards ? areaHeight - handleSize : 0;
    final double handleLeftRelative = (areaWidth / 2) - (handleSize / 2);
    final double panelTopRelative = opensUpwards ? 0 : handleSize + panelGap;
    final Alignment transitionAlignment = opensUpwards ? Alignment.bottomCenter : Alignment.topCenter;

    return Positioned(
      left: areaLeft,
      top: areaTop,
      width: areaWidth,
      height: areaHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pannello
          if (_showPanel)
            Positioned(
              top: panelTopRelative,
              left: 0,
              width: panelWidth,
              child: _buildPanel(transitionAlignment),
            ),

          // Handle "+"
          Positioned(
            left: handleLeftRelative,
            top: handleTopRelative,
            child: GestureDetector(
              onTap: _togglePanel,
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
    );
  }

  Widget _buildPanel(Alignment alignment) {
    return FadeTransition(
      opacity: _panelAnimation,
      child: ScaleTransition(
        scale: _panelAnimation,
        alignment: alignment,
        child: NodeCreationPanel(
          onNodeCreated: _closePanel,
          sourceNodeId: widget.sourceNode.id,
          canvasConstraints: widget.canvasConstraints,
          fromPort: _resolvePort(),
        ),
      ),
    );
  }

  Offset _getHandleCenter() {
    final node = widget.sourceNode;
    const gap = 8.0;
    switch (widget.direction) {
      case HandleDirection.bottom:
        return Offset(node.x + node.width / 2, node.y + node.height + gap + (handleSize / 2));
      case HandleDirection.top:
        return Offset(node.x + node.width / 2, node.y - gap - (handleSize / 2));
      case HandleDirection.left:
        return Offset(node.x - gap - (handleSize / 2), node.y + node.height / 2);
      case HandleDirection.right:
        return Offset(node.x + node.width + gap + (handleSize / 2), node.y + node.height / 2);
    }
  }

  String? _resolvePort() {
    if (widget.sourceNode.kind == FlowNodeKind.decision) {
      switch (widget.direction) {
        case HandleDirection.left: return 'false';
        case HandleDirection.right: return 'true';
        default: return null;
      }
    }
    return null;
  }
}


// La classe NodeCreationPanel rimane invariata
class NodeCreationPanel extends StatelessWidget {
  final String sourceNodeId;
  final VoidCallback onNodeCreated;
  final BoxConstraints canvasConstraints;
  final String? fromPort;

  const NodeCreationPanel({
    super.key,
    required this.sourceNodeId,
    required this.onNodeCreated,
    required this.canvasConstraints,
    this.fromPort,
  });


  /// Gestisce la creazione di un nuovo nodo o il collegamento a un nodo 'End' esistente.
  void _createNode(BuildContext context, FlowNodeKind kind) async {
    try {
      final bloc = context.read<FlowchartBloc>();
      final flowState = bloc.state;

      if (kind == FlowNodeKind.end && flowState is FlowchartLoaded) {
        final bool alreadyHasEndNode = flowState.flowchart.nodes.any((n) => n.kind == FlowNodeKind.end);
        if (alreadyHasEndNode) {
          final bool? wantsToLink = await AppDialogs.showConfirmationDialog(
            context,
            title: 'Nodo Fine Esistente',
            message: 'Esiste già un nodo Fine. Vuoi creare un collegamento a quest\'ultimo?',
            confirmText: 'Collega',
            cancelText: 'Annulla',
          );
          if (wantsToLink == true) {
            bloc.add(LinkToExistingEnd(fromNodeId: sourceNodeId, fromPort: fromPort));
          }
        } else {
          bloc.add(AddNode(
            kind: FlowNodeKind.end,
            fromNodeId: sourceNodeId,
            fromPort: fromPort,
            canvasConstraints: canvasConstraints,
            initialData: const {'text': 'Fine'},
          ));
        }
        return;
      }

      List<MyFile>? filesForProcess;
      List<Map<String,String>>? decisionVariables;
      if (kind == FlowNodeKind.process) {
        final fsState = context.read<FileSystemBloc>().state;
        if (fsState is FileSystemLoaded) {
          final activeId = fsState.activeFileId;
          final filtered = fsState.files.where((f) => f.fileId != activeId).toList();
          if (filtered.isEmpty) {
            await AppDialogs.showInfoDialog(
              context,
              title: 'Nessun altro file disponibile',
              message: 'Per creare un nodo di processo devi avere almeno un altro file diverso da quello attivo.',
            );
            return;
          }
          filesForProcess = filtered;
        } else {
          await AppDialogs.showInfoDialog(
            context,
            title: 'File non pronti',
            message: 'Attendi il caricamento dei file prima di creare un nodo di processo.',
          );
          return;
        }
      }
      if (kind == FlowNodeKind.decision) {
        if (flowState is FlowchartLoaded) {
          final vars = <Map<String,String>>[];
          final seen = <String>{};
            for (final n in flowState.flowchart.nodes) {
              if (n.kind == FlowNodeKind.input) {
                final input = n as InputNode;
                for (final d in input.declarations) {
                  if (!seen.contains(d.name)) { // evita duplicati per nome
                    seen.add(d.name);
                    vars.add({'name': d.name, 'type': d.dataType});
                  }
                }
              }
            }
          decisionVariables = vars;
        } else {
          await AppDialogs.showInfoDialog(
            context,
            title: 'Diagramma non pronto',
            message: 'Le variabili non sono ancora disponibili. Riprova fra poco.',
          );
          return;
        }
      }

      final Map<String, dynamic>? nodeData = await AppDialogs.showNodeCreationDialog(
        context: context,
        kind: kind,
        files: filesForProcess,
        variables: decisionVariables,
      );

      if (nodeData != null) {
        bloc.add(AddNode(
          kind: kind,
          fromNodeId: sourceNodeId,
          fromPort: fromPort,
          canvasConstraints: canvasConstraints,
          initialData: nodeData,
        ));
      }
    } finally {
      onNodeCreated();
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
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
                icon: FontAwesomeIcons.download,
                label: 'Input',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createNode(context, FlowNodeKind.input),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.upload,
                label: 'Output',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createNode(context, FlowNodeKind.output),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.gear,
                label: 'Processo',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createNode(context, FlowNodeKind.process),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.codeBranch,
                label: 'Condizione',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createNode(context, FlowNodeKind.decision),
              ),
              const _Divider(),
              ShapeButton(
                icon: FontAwesomeIcons.flagCheckered,
                label: 'Fine',
                textColor: theme.colorScheme.onSurface,
                onPressed: () => _createNode(context, FlowNodeKind.end),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShapeButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? textColor;

  const ShapeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.textColor,
  });

  @override
  State<ShapeButton> createState() => _ShapeButtonState();
}

class _ShapeButtonState extends State<ShapeButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.textColor ?? CupertinoColors.activeBlue;
    final bgColor = _hovering
        ? effectiveColor.withOpacity(0.08)
        : Colors.transparent;
    return SizedBox(
      width: double.infinity,
      height: _CreationHandleState._buttonHeight,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: bgColor,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: effectiveColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(widget.icon, size: 18, color: effectiveColor),
                ],
              ),
            ),
          ),
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