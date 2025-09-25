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
  static const double panelWidth = 180.0;
  static const double panelGap = 12.0;
  static const double panelHeight = (NodeCreationPanel.buttonHeight * 5) + (4 * 1.0);

  @override
  void initState() {
    super.initState();
    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeOutCubic,
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

  void _closePanelOnAction() {
    if (_showPanel) {
      _togglePanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final handleCenter = _getHandleCenter();
    final handleTopLeft = Offset(
      handleCenter.dx - (handleSize / 2),
      handleCenter.dy - (handleSize / 2),
    );

    final bool opensUpwards = widget.direction == HandleDirection.bottom &&
        (widget.canvasConstraints.maxHeight - (handleTopLeft.dy + handleSize) < panelHeight + panelGap);

    final double panelTop = opensUpwards
        ? handleTopLeft.dy - panelHeight - panelGap
        : handleTopLeft.dy + handleSize + panelGap;

    final double panelLeft = handleCenter.dx - (panelWidth / 2);

    final Alignment transitionAlignment = opensUpwards ? Alignment.bottomCenter : Alignment.topCenter;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_showPanel)
          Positioned(
            left: panelLeft,
            top: panelTop,
            child: _buildPanel(transitionAlignment),
          ),
        Positioned(
          left: handleTopLeft.dx,
          top: handleTopLeft.dy,
          child: GestureDetector(
            onTap: _togglePanel,
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: _showPanel ? Colors.grey.shade600 : Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)) ],
              ),
              child: AnimatedRotation(
                turns: _showPanel ? 0.125 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(Alignment alignment) {
    return FadeTransition(
      opacity: _panelAnimation,
      child: ScaleTransition(
        scale: _panelAnimation,
        alignment: alignment,
        child: NodeCreationPanel(
          onNodeCreated: _closePanelOnAction,
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
      case HandleDirection.bottom: return Offset(node.x + node.width / 2, node.y + node.height + gap + (handleSize / 2));
      case HandleDirection.top: return Offset(node.x + node.width / 2, node.y - gap - (handleSize / 2));
      case HandleDirection.left: return Offset(node.x - gap - (handleSize / 2), node.y + node.height / 2);
      case HandleDirection.right: return Offset(node.x + node.width + gap + (handleSize / 2), node.y + node.height / 2);
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

class NodeCreationPanel extends StatelessWidget {
  final String sourceNodeId;
  final VoidCallback onNodeCreated;
  final BoxConstraints canvasConstraints;
  final String? fromPort;

  static const double buttonHeight = 44.0;

  const NodeCreationPanel({
    super.key,
    required this.sourceNodeId,
    required this.onNodeCreated,
    required this.canvasConstraints,
    this.fromPort,
  });

  // **FIX**: Implementata la logica completa per chiamare i dialoghi e il BLoC.
  void _createNode(BuildContext context, FlowNodeKind kind) async {
    try {
      final bloc = context.read<FlowchartBloc>();
      final flowState = bloc.state;

      if (kind == FlowNodeKind.end && flowState is FlowchartLoaded) {
        final hasEndNode = flowState.flowchart.nodes.any((n) => n.kind == FlowNodeKind.end);
        if (hasEndNode) {
          bloc.add(LinkToExistingEnd(fromNodeId: sourceNodeId, fromPort: fromPort));
          return;
        }
      }

      List<MyFile>? filesForProcess;
      // --- MODIFICA: La lista ora è di tipo VariableDeclaration e ha un nome generico ---
      List<VariableDeclaration>? variablesForDialog;

      if (kind == FlowNodeKind.process) {
        final fsState = context.read<FileSystemBloc>().state;
        if (fsState is FileSystemLoaded) {
          filesForProcess = fsState.files.where((f) => f.fileId != fsState.activeFileId).toList();
        }
      }

      // --- MODIFICA: Popoliamo la lista per entrambi i tipi di nodo, Decision e Output ---
      if (kind == FlowNodeKind.decision || kind == FlowNodeKind.output) {
        if (flowState is FlowchartLoaded) {
          // Usiamo direttamente la lista di variabili dal BLoC
          variablesForDialog = flowState.flowchart.variables;
        }
      }

      final Map<String, dynamic>? nodeData = await AppDialogs.showNodeCreationDialog(
        context: context,
        kind: kind,
        files: filesForProcess,
        variables: variablesForDialog, // Passiamo la lista corretta
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
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          width: _CreationHandleState.panelWidth,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withAlpha(235),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShapeButton(icon: FontAwesomeIcons.download, label: 'Input', onPressed: () => _createNode(context, FlowNodeKind.input)),
              const _Divider(),
              ShapeButton(icon: FontAwesomeIcons.upload, label: 'Output', onPressed: () => _createNode(context, FlowNodeKind.output)),
              const _Divider(),
              ShapeButton(icon: FontAwesomeIcons.gear, label: 'Processo', onPressed: () => _createNode(context, FlowNodeKind.process)),
              const _Divider(),
              ShapeButton(icon: FontAwesomeIcons.codeBranch, label: 'Condizione', onPressed: () => _createNode(context, FlowNodeKind.decision)),
              const _Divider(),
              ShapeButton(icon: FontAwesomeIcons.flagCheckered, label: 'Fine', onPressed: () => _createNode(context, FlowNodeKind.end)),
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

  const ShapeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<ShapeButton> createState() => _ShapeButtonState();
}

class _ShapeButtonState extends State<ShapeButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = _isHovering ? theme.colorScheme.onSurface.withOpacity(0.08) : Colors.transparent;

    return SizedBox(
      width: double.infinity,
      height: NodeCreationPanel.buttonHeight,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: bgColor,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(widget.icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
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
      color: Theme.of(context).dividerColor.withOpacity(0.5),
    );
  }
}