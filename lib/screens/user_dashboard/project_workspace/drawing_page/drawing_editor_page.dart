import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_thesis/config/services/dialog_service/app_dialogs.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:universal_html/html.dart' as html;

/// 🎨 Drawing Editor - Professional Web-First Interface
class DrawingEditorPage extends StatefulWidget {
  const DrawingEditorPage({super.key});

  @override
  State<DrawingEditorPage> createState() => _DrawingEditorPageState();
}

class _DrawingEditorPageState extends State<DrawingEditorPage> {
  // --- DRAWING STATE (Logic Preserved) ---
  bool _drawingMode = true; // true: Pencil, false: Eraser
  final List<Stroke> _strokes = [];
  Stroke? _currentStroke;
  final GlobalKey _canvasKey = GlobalKey();

  // --- TOOL STATE ---
  double _strokeWidth = 2.0;
  double _eraserWidth = 16.0;
  late Color _strokeColor;
  late List<Color> _availableColors;

  // --- BACKGROUND STATE (Logic Preserved) ---
  Uint8List? _bgBytes;
  ImageProvider? _bgImage;
  bool _useBackground = false;
  double? _bgImageWidth;
  double? _bgImageHeight;
  Size? _canvasSize;
  Rect? _currentImageBox;

  @override
  void initState() {
    super.initState();
    _loadScreenshotFromStorage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = FluentTheme.of(context);
    _strokeColor = theme.brightness == Brightness.light
        ? const Color(0xFF03256C) // Primary blue from your theme
        : const Color(0xFF06BEE1); // Accent from your theme

    // Theme-based color palette
    _availableColors = [
      theme.brightness == Brightness.light
          ? const Color(0xFF03256C) // Primary blue
          : const Color(0xFFE2E8F0), // Light text
      theme.brightness == Brightness.light
          ? const Color(0xFF64748B) // Secondary text
          : const Color(0xFF94A3B8), // Tertiary text
      theme.brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF222222), // Dark surface
      theme.brightness == Brightness.light
          ? const Color(0xFFDC2626) // Error color
          : const Color(0xFFEF4444),
      theme.brightness == Brightness.light
          ? const Color(0xFFD97706) // Warning color
          : const Color(0xFFF59E0B),
      theme.brightness == Brightness.light
          ? const Color(0xFF0284C7) // Info color
          : const Color(0xFF06BEE1),
      theme.brightness == Brightness.light
          ? const Color(0xFF059669) // Success color
          : const Color(0xFF10B981),
      theme.brightness == Brightness.light
          ? const Color(0xFF7C3AED) // Purple accent
          : const Color(0xFF8B5CF6),
    ];
  }

  // --- MANAGEMENT METHODS (Logic Preserved) ---

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
    } catch (_) {}
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

  void _setDrawingMode(bool isDrawing) {
    setState(() => _drawingMode = isDrawing);
  }

  void _startNormalizedStroke(Offset localPos) {
    if (_canvasSize == null) return;
    final canvasSize = _canvasSize!;
    final bool relToImage = _useBackground && _currentImageBox != null;
    Rect refBox = relToImage ? _currentImageBox! : Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    double nx = (localPos.dx - refBox.left) / refBox.width;
    double ny = (localPos.dy - refBox.top) / refBox.height;
    final stroke = Stroke(
      points: [Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0))],
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
    if (_currentStroke == null || !_currentStroke!.normalized || _canvasSize == null) return;
    final canvasSize = _canvasSize!;
    Rect refBox = (_currentStroke!.relativeToImage && _currentImageBox != null)
        ? _currentImageBox!
        : Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    double nx = (localPos.dx - refBox.left) / refBox.width;
    double ny = (localPos.dy - refBox.top) / refBox.height;
    setState(() {
      _currentStroke!.points.add(Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0)));
    });
  }

  void _endStroke() => setState(() => _currentStroke = null);

  void _clearAllStrokes() async {
    final confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: "Conferma Cancellazione",
      message: "Sei sicuro di voler cancellare l'intero disegno? L'azione è irreversibile.",
      confirmText: "Cancella Tutto",
      isDestructive: true,
    );
    if (confirmed == true) {
      setState(() => _strokes.clear());
    }
  }

  void _toggleBackground() {
    if (_bgImage == null) return;
    setState(() => _useBackground = !_useBackground);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      // 🎯 Professional Toolbar Header
      header: Container(
        height: 80, // Generous height for web
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: theme.resources.layerFillColorDefault,
          border: Border(
            bottom: BorderSide(
              color: theme.resources.dividerStrokeColorDefault,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: EditorToolbar(
          drawingMode: _drawingMode,
          strokeWidth: _strokeWidth,
          eraserWidth: _eraserWidth,
          strokeColor: _strokeColor,
          availableColors: _availableColors,
          onToggleDrawingMode: () => _setDrawingMode(true),
          onToggleEraserMode: () => _setDrawingMode(false),
          onStrokeWidthChanged: (v) => setState(() => _strokeWidth = v),
          onEraserWidthChanged: (v) => setState(() => _eraserWidth = v),
          onColorSelected: (c) => setState(() => _strokeColor = c),
          onClearAll: _clearAllStrokes,
          useBackground: _useBackground,
          backgroundAvailable: _bgImage != null,
          onToggleBackground: (v) => _toggleBackground(),
        ),
      ),

      // 🎯 Drawing Canvas Content
      content: Container(
        decoration: BoxDecoration(
          color: theme.resources.layerFillColorAlt,
        ),
        child: DrawingCanvas(
          canvasKey: _canvasKey,
          strokes: _strokes,
          backgroundImage: _useBackground ? _bgImage : null,
          imageWidth: _bgImageWidth,
          imageHeight: _bgImageHeight,
          useBackground: _useBackground,
          onGeometry: (size, imageBox) {
            _canvasSize = size;
            _currentImageBox = imageBox;
          },
          onPanStart: _startNormalizedStroke,
          onPanUpdate: _appendPoint,
          onPanEnd: _endStroke,
        ),
      ),
    );
  }
}

// ============================================================================
// 🎨 PROFESSIONAL TOOLBAR - Complete Redesign
// ============================================================================

class EditorToolbar extends StatelessWidget {
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
  final bool useBackground;
  final bool backgroundAvailable;
  final ValueChanged<bool> onToggleBackground;

  const EditorToolbar({
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
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        // 🎯 Tools Section
        _ToolSection(
          title: 'Strumenti',
          children: [
            _ToggleTool(
              icon: FontAwesomeIcons.pencil,
              label: 'Matita',
              isActive: drawingMode,
              onPressed: onToggleDrawingMode,
            ),
            const SizedBox(width: 8),
            _ToggleTool(
              icon: FontAwesomeIcons.eraser,
              label: 'Gomma',
              isActive: !drawingMode,
              onPressed: onToggleEraserMode,
            ),
          ],
        ),

        // 🎯 Separator
        _VerticalSeparator(),

        // 🎯 Size Section
        _ToolSection(
          title: drawingMode ? 'Spessore Tratto' : 'Dimensione Gomma',
          children: [
            _SizeControl(
              value: drawingMode ? strokeWidth : eraserWidth,
              min: drawingMode ? 1.0 : 5.0,
              max: drawingMode ? 15.0 : 60.0,
              onChanged: drawingMode ? onStrokeWidthChanged : onEraserWidthChanged,
              displayValue: drawingMode
                  ? '${strokeWidth.toInt()}px'
                  : '${eraserWidth.toInt()}px',
            ),
          ],
        ),

        // 🎯 Separator
        _VerticalSeparator(),

        // 🎯 Colors Section (only for drawing mode)
        if (drawingMode) ...[
          _ToolSection(
            title: 'Colore',
            children: [
              _ColorPalette(
                colors: availableColors,
                selectedColor: strokeColor,
                onColorSelected: onColorSelected,
              ),
            ],
          ),

          _VerticalSeparator(),
        ],

        // 🎯 Background Section
        _ToolSection(
          title: 'Sfondo',
          children: [
            _BackgroundToggle(
              useBackground: useBackground,
              backgroundAvailable: backgroundAvailable,
              onToggle: onToggleBackground,
            ),
          ],
        ),

        const Spacer(),

        // 🎯 Actions Section
        _ActionButton(
          icon: FontAwesomeIcons.trash,
          label: 'Pulisci',
          onPressed: onClearAll,
          isDestructive: true,
        ),
      ],
    );
  }
}

// --- TOOLBAR COMPONENTS ---

/// 🎨 Tool Section Container
class _ToolSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ToolSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Text(
            title,
            style: theme.typography.caption?.copyWith(
              color: theme.typography.body?.color?.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ],
      ),
    );
  }
}

/// 🎨 Toggle Tool Button
class _ToggleTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _ToggleTool({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Tooltip(
      message: label,
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          final isHovering = states.contains(ButtonStates.hovered);
          final isPressed = states.contains(ButtonStates.pressed);

          Color backgroundColor;
          Color foregroundColor;

          if (isActive) {
            backgroundColor = theme.accentColor.defaultBrushFor(theme.brightness);
            foregroundColor = theme.brightness == Brightness.light
                ? Colors.white
                : Colors.black;
          } else if (isPressed) {
            backgroundColor = theme.resources.subtleFillColorTertiary;
            foregroundColor = theme.resources.textFillColorPrimary;
          } else if (isHovering) {
            backgroundColor = theme.resources.subtleFillColorSecondary;
            foregroundColor = theme.resources.textFillColorPrimary;
          } else {
            backgroundColor = Colors.transparent;
            foregroundColor = theme.resources.textFillColorPrimary;
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 32,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: isActive
                  ? null
                  : Border.all(
                color: theme.resources.controlStrokeColorDefault,
              ),
            ),
            child: Center(
              child: FaIcon(
                icon,
                size: 16,
                color: foregroundColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 🎨 Size Control Slider
class _SizeControl extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String displayValue;

  const _SizeControl({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: theme.resources.cardBackgroundFillColorSecondary,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.resources.cardStrokeColorDefault,
            ),
          ),
          child: Text(
            displayValue,
            style: theme.typography.caption?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: theme.resources.textFillColorPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// 🎨 Color Palette
class _ColorPalette extends StatelessWidget {
  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPalette({
    required this.colors,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: colors.map((color) {
        final isSelected = color == selectedColor;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _ColorSwatch(
            color: color,
            isSelected: isSelected,
            onPressed: () => onColorSelected(color),
          ),
        );
      }).toList(),
    );
  }
}

/// 🎨 Individual Color Swatch
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Tooltip(
      message: 'Seleziona colore',
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          final isHovering = states.contains(ButtonStates.hovered);
          final isPressed = states.contains(ButtonStates.pressed);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? theme.accentColor.defaultBrushFor(theme.brightness)
                    : (isHovering
                    ? theme.resources.controlStrokeColorDefault
                    : Colors.transparent),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected || isHovering ? [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.15),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ] : null,
            ),
            child: isPressed
                ? Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
            )
                : null,
          );
        },
      ),
    );
  }
}

/// 🎨 Background Toggle
class _BackgroundToggle extends StatelessWidget {
  final bool useBackground;
  final bool backgroundAvailable;
  final ValueChanged<bool> onToggle;

  const _BackgroundToggle({
    required this.useBackground,
    required this.backgroundAvailable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        FaIcon(
          FontAwesomeIcons.image,
          size: 14,
          color: backgroundAvailable
              ? theme.resources.textFillColorPrimary
              : theme.resources.textFillColorDisabled,
        ),
        const SizedBox(width: 8),
        ToggleSwitch(
          checked: useBackground,
          onChanged: backgroundAvailable ? onToggle : null,
        ),
      ],
    );
  }
}

/// 🎨 Action Button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final Color iconColor = isDestructive
        ? (theme.brightness == Brightness.light
        ? const Color(0xFFDC2626)
        : const Color(0xFFEF4444))
        : theme.resources.textFillColorPrimary;

    return Tooltip(
      message: label,
      child: Button(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// 🎨 Vertical Separator
class _VerticalSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.resources.dividerStrokeColorDefault,
    );
  }
}

// ============================================================================
// 🎨 DRAWING CANVAS - Enhanced Design
// ============================================================================

class DrawingCanvas extends StatelessWidget {
  final GlobalKey canvasKey;
  final List<Stroke> strokes;
  final ImageProvider? backgroundImage;
  final double? imageWidth;
  final double? imageHeight;
  final bool useBackground;
  final void Function(Size canvasSize, Rect? imageBox) onGeometry;
  final ValueChanged<Offset> onPanStart;
  final ValueChanged<Offset> onPanUpdate;
  final VoidCallback onPanEnd;

  const DrawingCanvas({
    super.key,
    required this.canvasKey,
    required this.strokes,
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
    final theme = FluentTheme.of(context);

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          final imageBox = _computeImageBox(canvasSize);
          onGeometry(canvasSize, imageBox);

          return GestureDetector(
            onPanStart: (details) {
              final box = context.findRenderObject() as RenderBox;
              onPanStart(box.globalToLocal(details.globalPosition));
            },
            onPanUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              onPanUpdate(box.globalToLocal(details.globalPosition));
            },
            onPanEnd: (_) => onPanEnd(),
            child: Container(
              key: canvasKey,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? Colors.white
                    : theme.resources.layerFillColorAlt,
                image: backgroundImage != null
                    ? DecorationImage(
                  image: backgroundImage!,
                  fit: BoxFit.contain,
                )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              margin: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: SketchPainter(strokes: strokes, imageBox: imageBox),
                size: Size.infinite,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 🎨 DRAWING MODELS - Logic Preserved
// ============================================================================

class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;
  final bool normalized;
  final bool relativeToImage;

  Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
    this.normalized = false,
    this.relativeToImage = false,
  });
}

class SketchPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Rect? imageBox;

  SketchPainter({required this.strokes, required this.imageBox});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke;

      if (stroke.isEraser) {
        paint.blendMode = BlendMode.clear;
      } else {
        paint.color = stroke.color;
      }

      Offset _denorm(Offset p) {
        if (!stroke.normalized) return p;
        final box = (stroke.relativeToImage && imageBox != null)
            ? imageBox!
            : Rect.fromLTWH(0, 0, size.width, size.height);
        return Offset(
            box.left + p.dx * box.width,
            box.top + p.dy * box.height
        );
      }

      // Draw stroke path
      if (stroke.points.length > 1) {
        final path = Path();
        path.moveTo(_denorm(stroke.points.first).dx, _denorm(stroke.points.first).dy);

        for (int i = 1; i < stroke.points.length; i++) {
          final point = _denorm(stroke.points[i]);
          path.lineTo(point.dx, point.dy);
        }

        canvas.drawPath(path, paint);
      } else if (stroke.points.isNotEmpty) {
        // Single point
        final point = _denorm(stroke.points.first);
        canvas.drawCircle(point, stroke.width / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SketchPainter old) =>
      old.strokes != strokes || old.imageBox != imageBox;
}