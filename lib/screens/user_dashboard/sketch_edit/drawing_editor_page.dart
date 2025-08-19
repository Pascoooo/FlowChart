import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;


class DrawingEditorPage extends StatefulWidget {
  const DrawingEditorPage({Key? key}) : super(key: key);

  @override
  State<DrawingEditorPage> createState() => _DrawingEditorPageState();
}

class _DrawingEditorPageState extends State<DrawingEditorPage> {
  bool _drawingMode = true;
  bool _eraserMode = false;
  List<Offset?> points = [];
  List<Offset?> erasedPoints = [];
  final TransformationController _transformationController = TransformationController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor di Disegno"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // Pulsante per reimpostare lo zoom
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: () => _transformationController.value = Matrix4.identity(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra degli strumenti semplificata
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Matita
                IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      border: _drawingMode
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit),
                  ),
                  tooltip: "Matita",
                  onPressed: () {
                    setState(() {
                      _drawingMode = true;
                      _eraserMode = false;
                    });
                  },
                ),
                // Gomma
                IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      border: _eraserMode
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_fix_normal),
                  ),
                  tooltip: "Gomma",
                  onPressed: () {
                    setState(() {
                      _drawingMode = false;
                      _eraserMode = true;
                    });
                  },
                ),
              ],
            ),
          ),

          // Area di disegno con zoom infinito
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(double.infinity), // Consente lo zoom e pan infiniti
              minScale: 0.1, // Zoom minimo
              maxScale: 10.0, // Zoom massimo
              child: GestureDetector(
                onPanUpdate: (details) {
                  // Converti le coordinate considerando la trasformazione attuale
                  final invertedMatrix = Matrix4.tryInvert(_transformationController.value);
                  if (invertedMatrix != null) {
                    final vector_math.Vector3 position = invertedMatrix.transform3(
                      vector_math.Vector3(details.localPosition.dx, details.localPosition.dy, 0),
                    );

                    setState(() {
                      if (_drawingMode && !_eraserMode) {
                        points.add(Offset(position.x, position.y));
                      } else if (_eraserMode && !_drawingMode) {
                        erasedPoints.add(Offset(position.x, position.y));
                      }
                    });
                  }
                },
                onPanEnd: (_) {
                  setState(() {
                    if (_drawingMode && !_eraserMode) points.add(null);
                    if (_eraserMode && !_drawingMode) erasedPoints.add(null);
                  });
                },
                child: Container(
                  width: 5000, // Area di disegno molto grande
                  height: 5000,
                  color: Colors.white,
                  child: CustomPaint(
                    painter: SketchPainter(points, erasedPoints),
                    size: const Size(5000, 5000),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}

// Classe SketchPainter aggiunta
class SketchPainter extends CustomPainter {
  final List<Offset?> points;
  final List<Offset?> erasedPoints;
  SketchPainter(this.points, this.erasedPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
    final eraser = Paint()
      ..color = Colors.transparent
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.clear;
    for (int i = 0; i < erasedPoints.length - 1; i++) {
      if (erasedPoints[i] != null && erasedPoints[i + 1] != null) {
        canvas.drawLine(erasedPoints[i]!, erasedPoints[i + 1]!, eraser);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}