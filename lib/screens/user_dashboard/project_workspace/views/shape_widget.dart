import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import 'painters.dart';

/// A widget representing a single shape in the flowchart, supporting drag and selection.
class ShapeWidget extends StatefulWidget {
  final FlowchartShape shape;
  final BoxConstraints canvasConstraints;
  final bool isSelected;

  const ShapeWidget({
    required this.shape,
    required this.canvasConstraints,
    required this.isSelected,
    required ValueKey<String> key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ShapeWidgetState();
  }
}

class _ShapeWidgetState extends State<ShapeWidget> {
  late Offset _dragPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _dragPosition = Offset(widget.shape.x, widget.shape.y);
  }

  @override
  void didUpdateWidget(covariant ShapeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging &&
        (oldWidget.shape.x != widget.shape.x ||
            oldWidget.shape.y != widget.shape.y)) {
      _dragPosition = Offset(widget.shape.x, widget.shape.y);
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
    final width = widget.shape.width;
    final height = widget.shape.height;

    return Positioned(
      left: _dragPosition.dx,
      top: _dragPosition.dy,
      child: GestureDetector(
        onTap: () {
          if (!widget.isSelected) {
            context.read<FlowchartBloc>().add(SelectShape(widget.shape.id));
            print('SHAPE: Selected shape ${widget.shape.id}');
          }
        },
        behavior: HitTestBehavior.opaque,
        onPanStart: widget.isSelected
            ? (details) => setState(() => _isDragging = true)
            : null,
        onPanUpdate: widget.isSelected
            ? (details) {
          setState(() {
            _dragPosition = Offset(
              _clampX(_dragPosition.dx + details.delta.dx, width),
              _clampY(_dragPosition.dy + details.delta.dy, height),
            );
          });
        }
            : null,
        onPanEnd: widget.isSelected
            ? (details) {
          final oldPosition = Offset(widget.shape.x, widget.shape.y);
          setState(() => _isDragging = false);
          context.read<FlowchartBloc>().add(
            UpdateShape(
              shapeId: widget.shape.id,
              newX: _dragPosition.dx,
              newY: _dragPosition.dy,
              oldX: oldPosition.dx,
              oldY: oldPosition.dy,
            ),
          );
        }
            : null,
        child: MouseRegion(
          cursor: widget.isSelected
              ? SystemMouseCursors.move
              : SystemMouseCursors.click,
          child: ShapeRenderer(
            shape: widget.shape,
            isSelected: widget.isSelected,
          ),
        ),
      ),
    );
  }
}

/// Renders a single shape based on its type (rectangle, circle, diamond).
class ShapeRenderer extends StatelessWidget {
  final FlowchartShape shape;
  final bool isSelected;

  const ShapeRenderer({super.key, required this.shape, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = shape.width;
    final height = shape.height;
    final text = shape.text;

    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: Colors.black87,
    );

    final borderColor =
    isSelected ? theme.colorScheme.primary : Colors.blueGrey.shade300;
    final borderWidth = isSelected ? 2.5 : 1.5;

    Widget shapeContent;

    switch (shape.type) {
      case 'diamond':
      case 'decision': // supporta il tipo logico usato nel modello
        shapeContent = CustomPaint(
          painter: DiamondPainter(
            color: Colors.white,
            borderColor: borderColor,
            strokeWidth: borderWidth,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Center(
              child: Text(text, textAlign: TextAlign.center, style: textStyle),
            ),
          ),
        );
        break;
      default:
        shapeContent = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              (shape.type == 'circle' || shape.type == 'start' || shape.type == 'end') ? 999 : 8,
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
            text,
            textAlign: TextAlign.center,
            style: textStyle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: shapeContent,
    );
  }
}