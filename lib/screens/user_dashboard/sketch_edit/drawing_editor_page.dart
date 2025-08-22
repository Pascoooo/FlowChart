import 'package:flutter/material.dart';

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

  // Dimensioni dell'area di disegno
  final Size _canvasSize = Size(800, 600);
  final GlobalKey _canvasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor di Disegno"),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Barra degli strumenti
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
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Container(
                            decoration: BoxDecoration(
                              border: _drawingMode
                                  ? Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
                        IconButton(
                          icon: Container(
                            decoration: BoxDecoration(
                              border: _eraserMode
                                  ? Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
                    if (_drawingMode)
                      SizedBox(
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
                      SizedBox(
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
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: "Cancella tutto",
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Cancella tutto"),
                        content: const Text(
                            "Vuoi davvero cancellare tutto il disegno?"),
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
                if (_drawingMode)
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableColors.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _strokeColor = _availableColors[index];
                                });
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _availableColors[index],
                                  shape: BoxShape.circle,
                                  border:
                                      _strokeColor == _availableColors[index]
                                          ? Border.all(
                                              color: Colors.white, width: 1.5)
                                          : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 2,
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
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    key: _canvasKey,
                    onPanStart: (details) {
                      final RenderBox box = _canvasKey.currentContext!
                          .findRenderObject() as RenderBox;
                      final localPos =
                          box.globalToLocal(details.globalPosition);

                      // Verifica che il punto sia all'interno dell'area di disegno
                      if (localPos.dx >= 0 &&
                          localPos.dx <= constraints.maxWidth &&
                          localPos.dy >= 0 &&
                          localPos.dy <= constraints.maxHeight) {
                        setState(() {
                          if (_drawingMode && !_eraserMode) {
                            currentStroke = Stroke(
                              points: [localPos],
                              color: _strokeColor,
                              width: _strokeWidth,
                            );
                            strokes.add(currentStroke!);
                          } else if (_eraserMode && !_drawingMode) {
                            currentStroke = Stroke(
                              points: [localPos],
                              color: Colors.transparent,
                              width: _eraserWidth,
                              isEraser: true,
                            );
                            strokes.add(currentStroke!);
                          }
                        });
                      }
                    },
                    onPanUpdate: (details) {
                      final RenderBox box = _canvasKey.currentContext!
                          .findRenderObject() as RenderBox;
                      final localPos =
                          box.globalToLocal(details.globalPosition);

                      if (currentStroke != null) {
                        // Limita i punti all'interno dell'area di disegno
                        final constrainedPos = Offset(
                          localPos.dx.clamp(0, constraints.maxWidth),
                          localPos.dy.clamp(0, constraints.maxHeight),
                        );

                        setState(() {
                          currentStroke!.points.add(constrainedPos);
                        });
                      }
                    },
                    onPanEnd: (_) {
                      setState(() {
                        if (currentStroke != null) {
                          currentStroke!.points.add(null); // Termina il tratto
                          currentStroke = null;
                        }
                      });
                    },
                    child: CustomPaint(
                      painter: SketchPainter(strokes),
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
