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
  List<Stroke> strokes = [];
  Stroke? currentStroke;

  List<Offset?> erasedPoints = [];
  double _strokeWidth = 2.0;
  double _eraserWidth = 16.0;
  Color _strokeColor = Colors.black;
  List<Color> _availableColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];
  final TransformationController _transformationController =
      TransformationController();

  @override
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
      ),
      body: Column(
        children: [
          // Barra degli strumenti migliorata
          // Barra degli strumenti riorganizzata
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Colonna strumenti disegno e slider
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Riga con matita e gomma
                    Row(
                      children: [
                        // Matita
                        IconButton(
                          icon: Container(
                            decoration: BoxDecoration(
                              border: _drawingMode
                                  ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2)
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
                                  ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2)
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
                    // Slider sotto gli strumenti
                    if (_drawingMode)
                      Container(
                        width: 120,
                        child: Slider(
                          value: _strokeWidth,
                          min: 1.0,
                          max: 10.0,
                          divisions: 5,
                          label: "${_strokeWidth.toInt()}",
                          onChanged: (value) {
                            setState(() {
                              _strokeWidth = value;
                            });
                          },
                        ),
                      ),
                    if (_eraserMode)
                      Container(
                        width: 120,
                        child: Slider(
                          value: _eraserWidth,
                          min: 5.0,
                          max: 50.0,
                          divisions: 5,
                          label: "${_eraserWidth.toInt()}",
                          onChanged: (value) {
                            setState(() {
                              _eraserWidth = value;
                            });
                          },
                        ),
                      ),
                  ],
                ),

                // Cestino
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: "Cancella tutto",
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Cancella tutto"),
                        content: const Text("Vuoi davvero cancellare tutto il disegno?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Annulla"),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                strokes.clear();
                              });
                              Navigator.pop(context);
                            },
                            child: const Text("Cancella"),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Tavolozza colori a destra del cestino
                if (_drawingMode)
                  Expanded(
                    child: SizedBox(
                      height: 30, // Ridotto da 40 a 30
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableColors.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0), // Ridotto da 4 a 2
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _strokeColor = _availableColors[index];
                                });
                              },
                              child: Container(
                                width: 22, // Ridotto da 30 a 22
                                height: 22, // Ridotto da 30 a 22
                                decoration: BoxDecoration(
                                  color: _availableColors[index],
                                  shape: BoxShape.circle,
                                  border: _strokeColor == _availableColors[index]
                                      ? Border.all(color: Colors.white, width: 1.5) // Ridotto da 2 a 1.5
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 2, // Ridotto da 3 a 2
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Area di disegno
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  if (_drawingMode && !_eraserMode) {
                    currentStroke = Stroke(
                      points: [details.localPosition],
                      color: _strokeColor,
                      width: _strokeWidth,
                    );
                    strokes.add(currentStroke!);
                  } else if (_eraserMode && !_drawingMode) {
                    currentStroke = Stroke(
                      points: [details.localPosition],
                      color: Colors.transparent,
                      width: _eraserWidth,
                      isEraser: true,
                    );
                    strokes.add(currentStroke!);
                  }
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  if (currentStroke != null) {
                    currentStroke!.points.add(details.localPosition);
                  }
                });
              },
              onPanEnd: (_) {
                setState(() {
                  if (currentStroke != null) {
                    currentStroke!.points.add(null); // Termina il tratto
                    currentStroke = null;
                  }
                });
              },
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: CustomPaint(
                  painter: SketchPainter(strokes),
                  size: Size.infinite,
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
  final List<Stroke> strokes;

  SketchPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()..strokeCap = StrokeCap.round;

      if (stroke.isEraser) {
        paint.color = Colors.transparent;
        paint.blendMode = BlendMode.clear;
      } else {
        paint.color = stroke.color;
      }

      paint.strokeWidth = stroke.width;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        if (stroke.points[i] != null && stroke.points[i + 1] != null) {
          canvas.drawLine(stroke.points[i]!, stroke.points[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Stroke {
  final List<Offset?> points;
  final Color color;
  final double width;
  final bool isEraser;

  Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });
}
