import 'package:flutter/material.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import 'creation_handle.dart';

class DecisionPortHandle extends StatefulWidget {
  final FlowchartShape decisionShape;
  final String port; // 'true' | 'false'
  final bool occupied;
  final BoxConstraints canvasConstraints;
  final bool isOpen; // controllo esterno
  final ValueChanged<bool> onToggle; // notifica apertura/chiusura

  const DecisionPortHandle({
    super.key,
    required this.decisionShape,
    required this.port,
    required this.occupied,
    required this.canvasConstraints,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<DecisionPortHandle> createState() => _DecisionPortHandleState();
}

class _DecisionPortHandleState extends State<DecisionPortHandle> with SingleTickerProviderStateMixin {
  static const double size = 22.0;
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.occupied) return;
    final opening = !widget.isOpen;
    widget.onToggle(opening);
    if (opening) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _closePanel() {
    if (widget.isOpen) {
      widget.onToggle(false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.occupied) return const SizedBox.shrink();
    final isTrue = widget.port == 'true';
    final centerX = isTrue ? widget.decisionShape.x + widget.decisionShape.width : widget.decisionShape.x;
    final centerY = widget.decisionShape.y + widget.decisionShape.height / 2;

    return Positioned(
      left: centerX - size / 2,
      top: centerY - size / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Icon(widget.isOpen ? Icons.close : Icons.add, size: 14, color: Colors.white),
            ),
          ),
          if (widget.isOpen)
            Positioned(
              left: isTrue ? size + 6 : null,
              right: isTrue ? null : size + 6,
              top: -20,
              child: ScaleTransition(
                scale: _scale,
                alignment: isTrue ? Alignment.centerLeft : Alignment.centerRight,
                child: ShapeCreationPanel(
                  sourceShapeId: widget.decisionShape.id,
                  fromPort: widget.port,
                  canvasConstraints: widget.canvasConstraints,
                  onShapeCreated: _closePanel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
