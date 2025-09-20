import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Assicurati che questi import puntino ai file corretti nel tuo progetto
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';

// MODIFICA CHIAVE: Aggiunto "implements FlowchartBloc"
class _StaticFlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> implements FlowchartBloc {
  _StaticFlowchartBloc(FlowchartState initialState) : super(initialState) {
    // Non registriamo handler per eventi - è solo per la visualizzazione
  }

  // Le seguenti implementazioni sono necessarie per soddisfare l'interfaccia di FlowchartBloc
  @override
  bool get canRedo => false;
  @override
  bool get canUndo => false;
  @override
  String? get nextRedoDescription => null;
  @override
  String? get nextUndoDescription => null;
}

class FlowchartPreview extends StatelessWidget {
  final String flowchartContent;

  const FlowchartPreview({super.key, required this.flowchartContent});

  // Ho migliorato il parsing per renderlo più sicuro
  FlowchartLoaded _parseFlowchartContent(String content) {
    try {
      if (content.trim().isEmpty) {
        return const FlowchartLoaded(shapes: [], selectedShapeId: null);
      }
      return FlowchartLoaded.fromJson(content);
    } catch (e) {
      // In caso di errore nel parsing, ritorna uno stato vuoto invece di crashare
      debugPrint('Errore durante il parsing del contenuto del flowchart: $e');
      return const FlowchartLoaded(shapes: [], selectedShapeId: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowchartState = _parseFlowchartContent(flowchartContent);

    return BlocProvider<FlowchartBloc>(
      create: (_) => _StaticFlowchartBloc(flowchartState),
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

// Canvas statico che scala il contenuto per adattarlo
class _StaticFlowchartCanvas extends StatelessWidget {
  const _StaticFlowchartCanvas();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is FlowchartLoaded) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final grid = Positioned.fill(
                  child: CustomPaint(painter: _GridPainter.fromTheme(context))
              );

              if (state.shapes.isEmpty) {
                return Stack(
                  children: [
                    grid,
                    const Center(
                      child: Text(
                        "Diagramma Vuoto",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Calcola il bounding box di tutte le forme
              final Rect? contentBounds = state.shapes.fold<Rect?>(
                null,
                    (previousValue, shape) {
                  final width = (shape.width <= 0) ? 100.0 : shape.width;
                  final height = (shape.height <= 0) ? 60.0 : shape.height;
                  final shapeRect = Rect.fromLTWH(shape.x, shape.y, width, height);

                  if (previousValue == null) return shapeRect;
                  return previousValue.expandToInclude(shapeRect);
                },
              );

              if (contentBounds == null || contentBounds.isEmpty) {
                return Stack(
                  children: [
                    grid,
                    const Center(child: Text("Contenuto non valido")),
                  ],
                );
              }

              // Calcola il fattore di scala con padding
              const double padding = 20.0;
              final availableWidth = constraints.maxWidth - (padding * 2);
              final availableHeight = constraints.maxHeight - (padding * 2);

              final scaleX = availableWidth / contentBounds.width;
              final scaleY = availableHeight / contentBounds.height;
              final scale = min(min(scaleX, scaleY), 1.0); // Non ingrandire oltre 1:1

              // Calcola l'offset per centrare
              final scaledContentWidth = contentBounds.width * scale;
              final scaledContentHeight = contentBounds.height * scale;

              final offsetX = (constraints.maxWidth - scaledContentWidth) / 2 - (contentBounds.left * scale);
              final offsetY = (constraints.maxHeight - scaledContentHeight) / 2 - (contentBounds.top * scale);

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  grid,
                  Transform.translate(
                    offset: Offset(offsetX, offsetY),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topLeft,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: state.shapes.map((shape) {
                          return Positioned(
                            left: shape.x,
                            top: shape.y,
                            child: _ShapeRenderer(shape: shape, isSelected: false),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
// Componenti di rendering - CORRETTI e MIGLIORATI
class _ShapeRenderer extends StatelessWidget {
  final FlowchartShape shape;
  final bool isSelected;

  const _ShapeRenderer({
    required this.shape,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final text = shape.text;
    final width = shape.width;
    final height = shape.height;

    const textStyle = TextStyle(
      fontSize: 12,
      color: Colors.black87,
      fontWeight: FontWeight.w500,
    );

    final borderColor = Colors.blueGrey.shade400;
    const borderWidth = 1.5;

    Widget shapeContent;

    switch (shape.type) {
      case 'diamond':
      case 'decision':
        shapeContent = CustomPaint(
          painter: _DiamondPainter(
            color: Colors.white,
            borderColor: borderColor,
            strokeWidth: borderWidth,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
        break;
      case 'circle':
      case 'start':
      case 'end':
        shapeContent = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: textStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;
      default:
        shapeContent = Container(
          width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
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

    return shapeContent;
  }
}

class _GridPainter extends CustomPainter {
  final Color minorColor;
  final Color majorColor;

  _GridPainter({
    required this.minorColor,
    required this.majorColor,
  });

  factory _GridPainter.fromTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _GridPainter(
      minorColor: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
      majorColor: (isDark ? Colors.white : Colors.black).withOpacity(0.15),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = minorColor
      ..strokeWidth = 0.5;

    final majorPaint = Paint()
      ..color = majorColor
      ..strokeWidth = 1.0;

    const gridSize = 20.0;

    // Linee verticali
    for (double x = 0; x <= size.width; x += gridSize) {
      final isMajor = (x / gridSize) % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // Linee orizzontali
    for (double y = 0; y <= size.height; y += gridSize) {
      final isMajor = (y / gridSize) % 5 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorPaint : minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.minorColor != minorColor ||
        oldDelegate.majorColor != majorColor;
  }
}

class _DiamondPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double strokeWidth;

  _DiamondPainter({
    required this.color,
    required this.borderColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();

    // Riempimento
    canvas.drawPath(path, Paint()..color = color);

    // Bordo
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}