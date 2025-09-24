import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flowchart_thesis/config/services/dialog_service/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

class DrawingEditorPage extends StatefulWidget {
  const DrawingEditorPage({super.key});

  @override
  State<DrawingEditorPage> createState() => _DrawingEditorPageState();
}

class _DrawingEditorPageState extends State<DrawingEditorPage> {
  bool _drawingMode = true;
  final List<Stroke> _strokes = [];
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

  Uint8List? _bgBytes;
  ImageProvider? _bgImage;
  bool _useBackground = false; // switch stato
  double? _bgImageWidth;
  double? _bgImageHeight;
  Size? _canvasSize; // aggiornato dinamicamente
  Rect? _currentImageBox; // bounding box attuale dell'immagine scalata

  @override
  void initState() {
    super.initState();
    _loadScreenshotFromStorage();
  }

  void _loadScreenshotFromStorage() {
    try {
      final b64 = html.window.localStorage['editor_last_screenshot'];
      if (b64 != null && b64.isNotEmpty) {
        final bytes = base64Decode(b64);
        _decodeImageDimensions(bytes);
        setState(() {
          _bgBytes = bytes;
          _bgImage = MemoryImage(bytes);
        });
      }
    } catch (_) {
      // ignoriamo errori di parsing
    }
  }

  Future<void> _decodeImageDimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _bgImageWidth = frame.image.width.toDouble();
          _bgImageHeight = frame.image.height.toDouble();
        });
      }
    } catch (_) {}
  }

  void _toggleBackground() {
    if (_bgImage == null) return; // nessuno screenshot disponibile
    setState(() => _useBackground = !_useBackground);
  }

  // Metodi per la gestione dello stato
  void _setDrawingMode(bool value) {
    setState(() => _drawingMode = value);
  }

  void _addStroke(Stroke stroke) { // legacy helper (manteniamo per retro compat)
    setState(() {
      _currentStroke = stroke;
      _strokes.add(stroke);
    });
  }

  void _startNormalizedStroke(Offset localPos) {
    if (_canvasSize == null) {
      // fallback legacy
      _addStroke(Stroke(points: [localPos], color: _drawingMode ? _strokeColor : Colors.transparent, width: _drawingMode ? _strokeWidth : _eraserWidth, isEraser: !_drawingMode));
      return;
    }
    final canvasSize = _canvasSize!;
    final bool relToImage = _useBackground && _currentImageBox != null;
    Rect refBox = relToImage ? _currentImageBox! : Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    double nx = (localPos.dx - refBox.left) / refBox.width;
    double ny = (localPos.dy - refBox.top) / refBox.height;
    nx = nx.clamp(0.0, 1.0);
    ny = ny.clamp(0.0, 1.0);
    final stroke = Stroke(
      points: [Offset(nx, ny)],
      color: _drawingMode ? _strokeColor : Colors.transparent,
      width: _drawingMode ? _strokeWidth : _eraserWidth,
      isEraser: !_drawingMode,
      normalized: true,
      relativeToImage: relToImage,
    );
    setState(() {
      _currentStroke = stroke;
      _strokes.add(stroke);
    });
  }

  void _appendPoint(Offset localPos) {
    if (_currentStroke == null) return;
    if (_currentStroke!.normalized) {
      if (_canvasSize == null) return;
      final canvasSize = _canvasSize!;
      Rect refBox;
      if (_currentStroke!.relativeToImage && _currentImageBox != null) {
        refBox = _currentImageBox!;
      } else {
        refBox = Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
      }
      double nx = (localPos.dx - refBox.left) / refBox.width;
      double ny = (localPos.dy - refBox.top) / refBox.height;
      nx = nx.clamp(0.0, 1.0);
      ny = ny.clamp(0.0, 1.0);
      setState(() {
        _currentStroke!.points.add(Offset(nx, ny));
      });
    } else {
      setState(() {
        _currentStroke!.points.add(localPos);
      });
    }
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
    final confirmed = AppDialogs.showConfirmationDialog(
      context,
      title: "Conferma",
      message: "Sei sicuro di voler cancellare tutto il disegno?",
      confirmText: "Cancella",
      cancelText: "Annulla",
    );
    confirmed.then((value) {
      if (value == true) {
        setState(() => _strokes.clear());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Forza tema chiaro solo per questa pagina
    final lightTheme = Theme.of(context).copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey[100],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
    );

    return Theme(
      data: lightTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(platformBrightness: Brightness.light),
        child: Scaffold(
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
                useBackground: _useBackground,
                backgroundAvailable: _bgImage != null,
                onToggleBackground: _toggleBackground,
              ),
              Expanded(
                child: DrawingCanvas(
                  canvasKey: _canvasKey,
                  strokes: _strokes,
                  isDrawingMode: _drawingMode,
                  strokeWidth: _strokeWidth,
                  eraserWidth: _eraserWidth,
                  strokeColor: _strokeColor,
                  backgroundImage: _useBackground ? _bgImage : null,
                  imageWidth: _bgImageWidth,
                  imageHeight: _bgImageHeight,
                  useBackground: _useBackground,
                  onGeometry: (size, imageBox) {
                    _canvasSize = size;
                    _currentImageBox = imageBox;
                  },
                  onPanStart: (details) => _startNormalizedStroke(details),
                  onPanUpdate: (details) => _appendPoint(details),
                  onPanEnd: _endStroke,
                ),
              ),
            ],
          ),
        ),
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
  // Nuovi parametri per toggle sfondo
  final bool useBackground;
  final bool backgroundAvailable;
  final VoidCallback onToggleBackground;

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
    required this.useBackground,
    required this.backgroundAvailable,
    required this.onToggleBackground,
  });

  @override
  Widget build(BuildContext context) {
    final toolbarColor = useBackground
        ? Colors.blueGrey.shade50
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: toolbarColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
        ),
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
              const SizedBox(width: 12),
              _BackgroundSwitch(
                isOn: useBackground,
                enabled: backgroundAvailable,
                onTap: onToggleBackground,
              ),
            ],
          ),
          // Slider
          SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: drawingMode
                      ? Slider(
                          value: strokeWidth,
                          min: 1.0,
                          max: 10.0,
                          divisions: 9,
                          activeColor: Colors.black,
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
          // Colori & Azioni
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
            color: isActive ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.transparent,
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
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: selectedColor == color
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}


class _BackgroundSwitch extends StatelessWidget {
  final bool isOn;
  final bool enabled;
  final VoidCallback onTap;
  const _BackgroundSwitch({required this.isOn, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final baseColor = enabled ? (isOn ? Colors.blueAccent : Colors.grey.shade300) : Colors.grey.shade200;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 70,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Stack(
          children: [
            // Divider centrale
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Indicatori testo
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      "OFF",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isOn ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "BG",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isOn ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Highlight animato
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
              curve: Curves.easeOut,
              child: Container(
                width: 32,
                height: 24,
                decoration: BoxDecoration(
                  color: enabled ? (isOn ? Colors.blue.shade600 : Colors.white) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
                ),
              ),
            ),
          ],
        ),
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
  final ImageProvider? backgroundImage; // nuovo
  final double? imageWidth;
  final double? imageHeight;
  final bool useBackground;
  final void Function(Size canvasSize, Rect? imageBox) onGeometry;

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
    this.backgroundImage,
    this.imageWidth,
    this.imageHeight,
    required this.useBackground,
    required this.onGeometry,
  });

  Rect? _computeImageBox(Size canvas) {
    if (!useBackground || imageWidth == null || imageHeight == null) return null;
    final iw = imageWidth!;
    final ih = imageHeight!;
    if (iw <= 0 || ih <= 0) return null;
    final scale = min(canvas.width / iw, canvas.height / ih);
    final dispW = iw * scale;
    final dispH = ih * scale;
    final left = (canvas.width - dispW) / 2;
    final top = (canvas.height - dispH) / 2;
    return Rect.fromLTWH(left, top, dispW, dispH);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          final imageBox = _computeImageBox(canvasSize);
          // comunica geometria al parent
          onGeometry(canvasSize, imageBox);
          return GestureDetector(
            onPanStart: (details) {
              final RenderBox box = canvasKey.currentContext?.findRenderObject() as RenderBox? ?? context.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              onPanStart(localPos);
            },
            onPanUpdate: (details) {
              final RenderBox box = canvasKey.currentContext?.findRenderObject() as RenderBox? ?? context.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.globalPosition);
              onPanUpdate(localPos);
            },
            onPanEnd: (_) => onPanEnd(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                image: backgroundImage != null
                    ? DecorationImage(
                        image: backgroundImage!,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      )
                    : null,
              ),
              child: CustomPaint(
                key: canvasKey,
                painter: SketchPainter(strokes: strokes, imageBox: imageBox),
                size: canvasSize,
              ),
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
  final List<Offset?> points; // se normalized=true: valori 0..1
  final Color color;
  final double width;
  final bool isEraser;
  final bool normalized; // nuovo
  final bool relativeToImage; // nuovo: normalizzato rispetto al box immagine

  Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
    this.normalized = false,
    this.relativeToImage = false,
  });
}

/// Painter personalizzato per disegnare i tratti.
class SketchPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Rect? imageBox; // bounding box attuale dell'immagine (se presente)
  SketchPainter({required this.strokes, required this.imageBox});

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

      Offset? _denorm(Offset? p) {
        if (p == null) return null;
        if (!stroke.normalized) return p; // legacy assoluto
        if (stroke.relativeToImage) {
          final box = imageBox ?? Rect.fromLTWH(0, 0, size.width, size.height);
            return Offset(box.left + p.dx * box.width, box.top + p.dy * box.height);
        } else {
          return Offset(p.dx * size.width, p.dy * size.height);
        }
      }

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final a = _denorm(stroke.points[i]);
        final b = _denorm(stroke.points[i + 1]);
        if (a != null && b != null) {
          canvas.drawLine(a, b, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SketchPainter old) => old.strokes != strokes || old.imageBox != imageBox;
}

