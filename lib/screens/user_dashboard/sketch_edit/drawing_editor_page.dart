import 'package:flutter/material.dart';

class DrawingEditorPage extends StatefulWidget {
  const DrawingEditorPage({super.key});

  @override
  State<DrawingEditorPage> createState() => _DrawingEditorPageState();
}

class _DrawingEditorPageState extends State<DrawingEditorPage> {
  bool _drawingMode = true;
  List<Stroke> _strokes = [];
  Stroke? _currentStroke;

  double _strokeWidth = 2.0;
  double _eraserWidth = 16.0;
  Color _strokeColor = Colors.black;
  final List<Color> _availableColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];

  final GlobalKey _canvasKey = GlobalKey();

  // Metodi per la gestione dello stato
  void _setDrawingMode(bool value) {
    setState(() => _drawingMode = value);
  }

  void _addStroke(Stroke stroke) {
    setState(() {
      _currentStroke = stroke;
      _strokes.add(stroke);
    });
  }

  void _addPointsToStroke(List<Offset?> points) {
    setState(() {});
  }

  void _endStroke() {
    setState(() {
      if (_currentStroke != null) {
        _currentStroke!.points.add(null);
        _currentStroke = null;
      }
    });
  }

  void _clearAllStrokes() {
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
                _strokes.clear();
              });
              Navigator.pop(context);
            },
            child: const Text("Cancella"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor di Disegno"),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          DrawingToolbar(
            drawingMode: _drawingMode,
            strokeWidth: _strokeWidth,
            eraserWidth: _eraserWidth,
            strokeColor: _strokeColor,
            availableColors: _availableColors,
            onToggleDrawingMode: () => _setDrawingMode(true),
            onToggleEraserMode: () => _setDrawingMode(false),
            onStrokeWidthChanged: (value) => setState(() => _strokeWidth = value),
            onEraserWidthChanged: (value) => setState(() => _eraserWidth = value),
            onColorSelected: (color) => setState(() => _strokeColor = color),
            onClearAll: _clearAllStrokes,
          ),
          Expanded(
            child: DrawingCanvas(
              canvasKey: _canvasKey,
              strokes: _strokes,
              isDrawingMode: _drawingMode,
              strokeWidth: _strokeWidth,
              eraserWidth: _eraserWidth,
              strokeColor: _strokeColor,
              onPanStart: (details) => _addStroke(Stroke(
                points: [details],
                color: _drawingMode ? _strokeColor : Colors.transparent,
                width: _drawingMode ? _strokeWidth : _eraserWidth,
                isEraser: !_drawingMode,
              )),
              onPanUpdate: (details) {
                if (_currentStroke != null) {
                  _currentStroke!.points.add(details);
                  _addPointsToStroke(_currentStroke!.points);
                }
              },
              onPanEnd: _endStroke,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------

/// Widget per la barra degli strumenti di disegno.
class DrawingToolbar extends StatelessWidget {
  final bool drawingMode;
  final double strokeWidth;
  final double eraserWidth;
  final Color strokeColor;
  final List<Color> availableColors;
  final VoidCallback onClearAll;
  final VoidCallback onToggleDrawingMode;
  final VoidCallback onToggleEraserMode;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<double> onEraserWidthChanged;
  final ValueChanged<Color> onColorSelected;

  const DrawingToolbar({
    super.key,
    required this.drawingMode,
    required this.strokeWidth,
    required this.eraserWidth,
    required this.strokeColor,
    required this.availableColors,
    required this.onClearAll,
    required this.onToggleDrawingMode,
    required this.onToggleEraserMode,
    required this.onStrokeWidthChanged,
    required this.onEraserWidthChanged,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sezione Strumenti
          Row(
            children: [
              _ToolButton(
                icon: Icons.edit_rounded,
                tooltip: "Matita",
                isActive: drawingMode,
                onTap: onToggleDrawingMode,
              ),
              const SizedBox(width: 8.0),
              _ToolButton(
                icon: Icons.auto_fix_normal_rounded,
                tooltip: "Gomma",
                isActive: !drawingMode,
                onTap: onToggleEraserMode,
              ),
            ],
          ),

          // Sezione Slider
          SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: drawingMode ? strokeWidth + 8 : eraserWidth / 2 + 8,
                  color: drawingMode ? strokeColor : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: drawingMode
                      ? Slider(
                    value: strokeWidth,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    activeColor: strokeColor,
                    onChanged: onStrokeWidthChanged,
                  )
                      : Slider(
                    value: eraserWidth,
                    min: 5.0,
                    max: 50.0,
                    divisions: 9,
                    onChanged: onEraserWidthChanged,
                  ),
                ),
              ],
            ),
          ),

          // Sezione Colori e Azioni
          Row(
            children: [
              _ColorPicker(
                availableColors: availableColors,
                selectedColor: strokeColor,
                onColorSelected: onColorSelected,
              ),
              const SizedBox(width: 16),
              _ToolButton(
                icon: Icons.delete_outline_rounded,
                tooltip: "Cancella tutto",
                isActive: false,
                onTap: onClearAll,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? Theme.of(context).primaryColor : Colors.grey[700],
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final List<Color> availableColors;
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPicker({
    required this.availableColors,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: availableColors.length,
        itemBuilder: (context, index) {
          final color = availableColors[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => onColorSelected(color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selectedColor == color
                      ? Border.all(color: Colors.white, width: 3.0)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: selectedColor == color
                    ? Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------------

/// Widget per l'area di disegno interattiva.
class DrawingCanvas extends StatelessWidget {
  final GlobalKey canvasKey;
  final List<Stroke> strokes;
  final bool isDrawingMode;
  final double strokeWidth;
  final double eraserWidth;
  final Color strokeColor;
  final ValueChanged<Offset> onPanStart;
  final ValueChanged<Offset> onPanUpdate;
  final VoidCallback onPanEnd;

  const DrawingCanvas({
    super.key,
    required this.canvasKey,
    required this.strokes,
    required this.isDrawingMode,
    required this.strokeWidth,
    required this.eraserWidth,
    required this.strokeColor,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanStart: (details) {
              final RenderBox box = canvasKey.currentContext!.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);

              if (localPos.dx >= 0 &&
                  localPos.dx <= constraints.maxWidth &&
                  localPos.dy >= 0 &&
                  localPos.dy <= constraints.maxHeight) {
                onPanStart(localPos);
              }
            },
            onPanUpdate: (details) {
              final RenderBox box = canvasKey.currentContext!.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              onPanUpdate(localPos);
            },
            onPanEnd: (_) => onPanEnd(),
            child: CustomPaint(
              key: canvasKey,
              painter: SketchPainter(strokes),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------------

/// Classe per rappresentare un tratto di disegno.
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

/// Painter personalizzato per disegnare i tratti.
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