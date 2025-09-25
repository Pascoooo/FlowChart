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
  final bool isReadOnly;

  const NodeWidget({
    required Key key,
    required this.node,
    required this.canvasConstraints,
    required this.isSelected,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _NodeWidgetState();
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

  double _clampX(double x) => x.clamp(10.0, widget.canvasConstraints.maxWidth - widget.node.width - 10.0);
  double _clampY(double y) => y.clamp(10.0, widget.canvasConstraints.maxHeight - widget.node.height - 10.0);

  @override
  Widget build(BuildContext context) {
    const double topPaddingForButton = 42.0;

    return Positioned(
      left: _dragPosition.dx,
      top: _dragPosition.dy,
      width: widget.node.width,
      height: widget.node.height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: widget.isReadOnly ? null : () {
              if (!widget.isSelected) {
                context.read<FlowchartBloc>().add(SelectNode(widget.node.id));
              }
            },
            behavior: HitTestBehavior.opaque,
            onPanStart: widget.isReadOnly || !widget.isSelected ? null : (details) => setState(() => _isDragging = true),
            onPanUpdate: widget.isReadOnly || !widget.isSelected ? null : (details) {
              setState(() {
                _dragPosition = Offset(
                  _clampX(_dragPosition.dx + details.delta.dx),
                  _clampY(_dragPosition.dy + details.delta.dy),
                );
              });
            },
            onPanEnd: widget.isReadOnly || !widget.isSelected ? null : (details) {
              setState(() => _isDragging = false);
              context.read<FlowchartBloc>().add(
                UpdateNodePosition(
                  nodeId: widget.node.id,
                  newX: _dragPosition.dx,
                  newY: _dragPosition.dy,
                  oldX: widget.node.x,
                  oldY: widget.node.y,
                ),
              );
            },
            child: MouseRegion(
              cursor: widget.isReadOnly ? SystemMouseCursors.basic : (widget.isSelected ? SystemMouseCursors.move : SystemMouseCursors.click),
              child: NodeRenderer(
                node: widget.node,
                isSelected: widget.isSelected,
              ),
            ),
          ),
          Positioned(
            top: -topPaddingForButton,
            child: AnimatedOpacity(
              opacity: widget.isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !widget.isSelected,
                child: _EyeButton(
                  onTap: () {
                    AppDialogs.showNodeDetailsDialog(context: context, node: widget.node);
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
      color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
      shape: const CircleBorder(),
      elevation: 4.0,
      shadowColor: Colors.black.withOpacity(0.2),
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

class NodeRenderer extends StatelessWidget {
  final FlowNode node;
  final bool isSelected;

  const NodeRenderer({super.key, required this.node, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
    );
    final borderColor = isSelected ? theme.colorScheme.primary : Colors.blueGrey.shade300;
    final borderWidth = isSelected ? 2.5 : 1.5;
    const fillColor = Colors.white;

    Widget nodeContent;

    // **FIX**: Ripristinata la struttura corretta. Il testo ora è DENTRO il CustomPaint.
    switch (node.kind) {
      case FlowNodeKind.decision:
        nodeContent = CustomPaint(
          painter: DiamondPainter(color: fillColor, borderColor: borderColor, strokeWidth: borderWidth),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(node.text, textAlign: TextAlign.center, style: textStyle),
              ),
            ),
          ),
        );
        break;
      case FlowNodeKind.input:
      case FlowNodeKind.output:
        nodeContent = CustomPaint(
          painter: ParallelogramPainter(fillColor: fillColor, borderColor: borderColor, strokeWidth: borderWidth, reversed: node.kind == FlowNodeKind.output),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            color: fillColor,
            borderRadius: BorderRadius.circular((node.kind == FlowNodeKind.start || node.kind == FlowNodeKind.end) ? 999 : 8),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [ if (isSelected) BoxShadow(color: theme.colorScheme.primary.withOpacity(0.25), blurRadius: 8) ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(node.text, textAlign: TextAlign.center, style: textStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
        );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: nodeContent,
    );
  }
}