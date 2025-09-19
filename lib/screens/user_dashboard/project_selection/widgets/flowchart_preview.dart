import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_bloc.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_event.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Un BLoC fittizio per il rendering statico, ora correttamente implementato.
class _EmptyFlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> implements FlowchartBloc {
  _EmptyFlowchartBloc(FlowchartState initialState) : super(initialState);

  @override
  bool get canRedo => false;

  @override
  bool get canUndo => false;

  @override
  String? get nextRedoDescription => null;

  @override
  String? get nextUndoDescription => null;

  // Implementazioni vuote per soddisfare i requisiti di 'Bloc'
  @override
  void onTransition(Transition<FlowchartEvent, FlowchartState> transition) {
    super.onTransition(transition);
    // No-op
  }
}


class FlowchartPreview extends StatelessWidget {
  final String flowchartContent;
  const FlowchartPreview({super.key, required this.flowchartContent});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FlowchartBloc>(
      create: (_) => _EmptyFlowchartBloc(FlowchartLoaded.fromJson(flowchartContent)),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.hardEdge,
          child: const _StaticFlowchartCanvas(),
        ),
      ),
    );
  }
}

class _StaticFlowchartCanvas extends StatelessWidget {
  const _StaticFlowchartCanvas();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is FlowchartLoaded) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // Adatta le forme allo spazio disponibile
              final scaleX = constraints.maxWidth / 800;
              final scaleY = constraints.maxHeight / 500;

              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _GridPainter.fromTheme(context)),
                  ),
                  if (state.shapes.isEmpty)
                    const Center(child: Text("Nessun contenuto")),
                  ...state.shapes.map((shape) {
                    return Positioned(
                      left: shape.x * scaleX,
                      top: shape.y * scaleY,
                      child: Transform.scale(
                        scale: (scaleX + scaleY) / 2 * 0.9,
                        child: _ShapeRenderer(shape: shape, isSelected: false),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

// --- Componenti di rendering copiati da workarea.dart ---
class _ShapeRenderer extends StatelessWidget {
  final FlowchartShape shape;
  final bool isSelected;
  const _ShapeRenderer({required this.shape, required this.isSelected});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (shape.properties['width'] as num?)?.toDouble() ?? 100;
    final height = (shape.properties['height'] as num?)?.toDouble() ?? 60;
    final text = (shape.properties['text'] as String?) ?? '';
    final textStyle = TextStyle(fontSize: 12, color: Colors.black87);
    final borderColor = Colors.blueGrey.shade300;
    final borderWidth = 1.5;

    Widget shapeContent;
    switch (shape.type) {
      case 'diamond':
        shapeContent = CustomPaint(
          painter: _DiamondPainter(color: Colors.white, borderColor: borderColor, strokeWidth: borderWidth),
          child: SizedBox(width: width, height: height, child: Center(child: Text(text, textAlign: TextAlign.center, style: textStyle))),
        );
        break;
      default:
        shapeContent = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(shape.type == 'circle' ? 999 : 8),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(text, textAlign: TextAlign.center, style: textStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
        );
    }
    return AnimatedContainer(duration: const Duration(milliseconds: 200), child: shapeContent);
  }
}

class _GridPainter extends CustomPainter {
  final Color minorColor;
  final Color majorColor;
  _GridPainter({required this.minorColor, required this.majorColor});
  factory _GridPainter.fromTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _GridPainter(
      minorColor: (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.14 : 0.10),
      majorColor: (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.30 : 0.18),
    );
  }
  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()..color = minorColor..strokeWidth = 1.0;
    final major = Paint()..color = majorColor..strokeWidth = 1.6;
    for (double x = 0, i = 0; x <= size.width + .5; x += 24, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (i % 4 == 0) ? major : minor);
    }
    for (double y = 0, i = 0; y <= size.height + .5; y += 24, i++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (i % 4 == 0) ? major : minor);
    }
  }
  @override
  bool shouldRepaint(covariant _GridPainter old) => old.minorColor != minorColor || old.majorColor != majorColor;
}

class _DiamondPainter extends CustomPainter {
  final Color color, borderColor;
  final double strokeWidth;
  _DiamondPainter({required this.color, required this.borderColor, required this.strokeWidth});
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)..lineTo(0, size.height / 2)..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()..color = borderColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(covariant _DiamondPainter old) => old.color != color || old.borderColor != borderColor || old.strokeWidth != strokeWidth;
}