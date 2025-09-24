// lib/screens/user_dashboard/project_workspace/views/node_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import 'painters.dart';

class NodeWidget extends StatefulWidget {
  final FlowNode node;
  final BoxConstraints canvasConstraints;
  final bool isSelected;
  final bool isReadOnly; // <-- MODIFICA: Aggiunto flag

  const NodeWidget({
    required this.node,
    required this.canvasConstraints,
    required this.isSelected,
    required Key key,
    this.isReadOnly = false, // <-- MODIFICA: Default a false
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _NodeWidgetState();
  }
}

class _NodeWidgetState extends State<NodeWidget> {
  late Offset _dragPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _dragPosition = Offset(widget.node.x, widget.node.y);
  }

  @override
  void didUpdateWidget(covariant NodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging &&
        (oldWidget.node.x != widget.node.x ||
            oldWidget.node.y != widget.node.y)) {
      _dragPosition = Offset(widget.node.x, widget.node.y);
    }
  }

  double _clampX(double x, double width) {
    const padding = 10.0;
    return x.clamp(padding, widget.canvasConstraints.maxWidth - width - padding);
  }

  double _clampY(double y, double height) {
    const padding = 10.0;
    return y.clamp(padding, widget.canvasConstraints.maxHeight - height - padding);
  }

  @override
  Widget build(BuildContext context) {
    const double topPaddingForButton = 42.0;

    return Positioned(
      left: _dragPosition.dx,
      top: _dragPosition.dy - topPaddingForButton,
      width: widget.node.width,
      height: widget.node.height + topPaddingForButton,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 0,
            child: GestureDetector(
              // <-- MODIFICA: Se in sola lettura, l'onTap è disabilitato (null) -->
              onTap: widget.isReadOnly ? null : () {
                if (!widget.isSelected) {
                  context.read<FlowchartBloc>().add(SelectNode(widget.node.id));
                }
              },
              behavior: HitTestBehavior.opaque,
              // <-- MODIFICA: Se in sola lettura, il trascinamento è disabilitato -->
              onPanStart: widget.isReadOnly || !widget.isSelected ? null : (details) => setState(() => _isDragging = true),
              onPanUpdate: widget.isReadOnly || !widget.isSelected ? null : (details) {
                setState(() {
                  _dragPosition = Offset(
                    _clampX(_dragPosition.dx + details.delta.dx, widget.node.width),
                    _clampY(_dragPosition.dy + details.delta.dy, widget.node.height),
                  );
                });
              },
              onPanEnd: widget.isReadOnly || !widget.isSelected ? null : (details) {
                final oldPosition = Offset(widget.node.x, widget.node.y);
                setState(() => _isDragging = false);
                context.read<FlowchartBloc>().add(
                  UpdateNodePosition(
                    nodeId: widget.node.id,
                    newX: _dragPosition.dx,
                    newY: _dragPosition.dy,
                    oldX: oldPosition.dx,
                    oldY: oldPosition.dy,
                  ),
                );
              },
              child: MouseRegion(
                // <-- MODIFICA: Il cursore non diventa "move" in sola lettura -->
                cursor: widget.isReadOnly ? SystemMouseCursors.basic : (widget.isSelected ? SystemMouseCursors.move : SystemMouseCursors.click),
                child: NodeRenderer(
                  node: widget.node,
                  isSelected: widget.isSelected,
                ),
              ),
            ),
          ),
          // <-- Il pulsante occhio rimane sempre visibile e funzionante -->
          Positioned(
            top: 0,
            child: AnimatedOpacity(
              opacity: widget.isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !widget.isSelected,
                child: _EyeButton(
                  onTap: () {
                    AppDialogs.showNodeDetailsDialog(
                      context: context,
                      node: widget.node,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _EyeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EyeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
      shape: const CircleBorder(),
      elevation: 4.0,
      shadowColor: Colors.black.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            Icons.visibility_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// La classe NodeRenderer rimane invariata
class NodeRenderer extends StatelessWidget {
  final FlowNode node;
  final bool isSelected;

  const NodeRenderer({super.key, required this.node, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: Colors.black87,
    );
    final borderColor = isSelected ? theme.colorScheme.primary : Colors.blueGrey.shade300;
    final borderWidth = isSelected ? 2.5 : 1.5;
    Widget nodeContent;

    switch (node.kind) {
      case FlowNodeKind.decision:
        nodeContent = CustomPaint(
          painter: DiamondPainter(
            color: Colors.white,
            borderColor: borderColor,
            strokeWidth: borderWidth,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Text(node.text, textAlign: TextAlign.center, style: textStyle),
            ),
          ),
        );
        break;
      case FlowNodeKind.input:
        nodeContent = CustomPaint(
          painter: ParallelogramPainter(
            fillColor: Colors.white,
            borderColor: borderColor,
            strokeWidth: borderWidth,
            reversed: false,
            drawShadow: isSelected,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(node.text, textAlign: TextAlign.center, style: textStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        );
        break;
      case FlowNodeKind.output:
        nodeContent = CustomPaint(
          painter: ParallelogramPainter(
            fillColor: Colors.white,
            borderColor: borderColor,
            strokeWidth: borderWidth,
            reversed: true,
            drawShadow: isSelected,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(node.text, textAlign: TextAlign.center, style: textStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        );
        break;
      default:
        nodeContent = Container(
          width: node.width,
          height: node.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              (node.kind == FlowNodeKind.start || node.kind == FlowNodeKind.end) ? 999 : 8,
            ),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? theme.colorScheme.primary.withAlpha(76)
                    : Colors.black12,
                blurRadius: isSelected ? 10 : 5,
                offset: Offset(0, isSelected ? 5 : 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(
            node.text,
            textAlign: TextAlign.center,
            style: textStyle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: nodeContent,
    );
  }
}