import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor di Disegno"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Torna alla pagina principale
            Navigator.of(context).pop();
          },
        ),
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

          // Area di disegno
          Expanded(
            child: ClipRect(
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    if (_drawingMode && !_eraserMode) {
                      points.add(details.localPosition);
                    } else if (_eraserMode && !_drawingMode) {
                      erasedPoints.add(details.localPosition);
                    }
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    if (_drawingMode && !_eraserMode) points.add(null);
                    if (_eraserMode && !_drawingMode) erasedPoints.add(null);
                  });
                },
                child: CustomPaint(
                  painter: SketchPainter(points, erasedPoints),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      ..color = Colors.white
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < erasedPoints.length - 1; i++) {
      if (erasedPoints[i] != null && erasedPoints[i + 1] != null) {
        canvas.drawLine(erasedPoints[i]!, erasedPoints[i + 1]!, eraser);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}