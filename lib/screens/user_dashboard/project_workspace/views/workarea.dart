import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';

// --- WIDGET PRINCIPALE DI AREA DI LAVORO ---

/// [WorkArea] è un contenitore stilizzato che ospita la tela del diagramma di flusso.
/// Gestisce l'aspetto esteriore come colore, ombra e bordi arrotondati.
class WorkArea extends StatelessWidget {
  final GlobalKey repaintKey;
  final bool showGrid;

  const WorkArea({super.key, required this.repaintKey, required this.showGrid});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withAlpha(25), // Alpha 0.1
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: _FlowchartCanvas(showGrid: showGrid),
      ),
    );
  }
}

// --- TELA DEL DIAGRAMMA DI FLUSSO ---

class _FlowchartCanvas extends StatelessWidget {
  final bool showGrid;
  const _FlowchartCanvas({required this.showGrid});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is FlowchartLoaded) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTap: () {
                  context.read<FlowchartBloc>().add(DeselectShape());
                },
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  children: [
                    // Disegna la griglia di sfondo se abilitata
                    if (showGrid)
                      Positioned.fill(
                        child: CustomPaint(painter: _GridPainter.fromTheme(context)),
                      ),

                    // Mostra un placeholder se non ci sono forme
                    if (state.shapes.isEmpty) const _EmptyCanvasPlaceholder(),

                    // Disegna tutte le forme presenti nello stato
                    for (final shape in state.shapes)
                      _ShapeWidget(
                        key: ValueKey(shape.id),
                        shape: shape,
                        canvasConstraints: constraints,
                        isSelected: state.selectedShapeId == shape.id,
                      ),
                  ],
                ),
              );
            },
          );
        }
        // Mostra un indicatore di caricamento durante lo stato iniziale
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}


// --- WIDGET PER LA GESTIONE DELLA SINGOLA FORMA (POSIZIONE E GESTURE) ---

/// [_ShapeWidget] è uno StatefulWidget che gestisce la posizione, la selezione
/// e il trascinamento di una singola forma sulla tela.
/// Delega la renderizzazione effettiva della forma a [_ShapeRenderer].
class _ShapeWidget extends StatefulWidget {
  final FlowchartShape shape;
  final BoxConstraints canvasConstraints;
  final bool isSelected;

  const _ShapeWidget({
    required this.shape,
    required this.canvasConstraints,
    required this.isSelected, required ValueKey<String> key,
  });

  @override
  State<_ShapeWidget> createState() => _ShapeWidgetState();
}

class _ShapeWidgetState extends State<_ShapeWidget> {
  // Usiamo un Offset per gestire la posizione durante il trascinamento
  late Offset _dragPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _dragPosition = Offset(widget.shape.x, widget.shape.y);
  }

  // Sincronizza la posizione se la forma viene spostata da un'altra parte (es. undo/redo)
  // senza interferire con un trascinamento in corso.
  @override
  void didUpdateWidget(covariant _ShapeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && (oldWidget.shape.x != widget.shape.x || oldWidget.shape.y != widget.shape.y)) {
      _dragPosition = Offset(widget.shape.x, widget.shape.y);
    }
  }

  // Funzioni di utility per mantenere la forma entro i limiti della tela
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
    final width = (widget.shape.properties['width'] as num?)?.toDouble() ?? 100;
    final height = (widget.shape.properties['height'] as num?)?.toDouble() ?? 60;

    return Positioned(
      left: _dragPosition.dx,
      top: _dragPosition.dy,
      child: GestureDetector(
        onTap: () {
          if (!widget.isSelected) {
            context.read<FlowchartBloc>().add(SelectShape(widget.shape.id));
          }
        },
        behavior: HitTestBehavior.opaque,
        onPanStart: widget.isSelected ? (details) => setState(() => _isDragging = true) : null,
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
              oldX: oldPosition.dx,  // Aggiungi questo
              oldY: oldPosition.dy,  // Aggiungi questo
            ),
          );
        }
            : null,
        child: MouseRegion(
          cursor: widget.isSelected ? SystemMouseCursors.move : SystemMouseCursors.click,
          child: _ShapeRenderer(
            shape: widget.shape,
            isSelected: widget.isSelected,
          ),
        ),
      ),
    );
  }
}

// --- WIDGET PER LA RENDERIZZAZIONE DELLA FORMA (ASPETTO GRAFICO) ---

/// [_ShapeRenderer] è un widget stateless che si occupa solo dell'aspetto
/// visivo della forma. Decide quale forma disegnare in base al `shape.type`.
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

    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: Colors.black87,
    );

    final borderColor = isSelected ? theme.colorScheme.primary : Colors.blueGrey.shade300;
    final borderWidth = isSelected ? 2.5 : 1.5;


    Widget shapeContent;

    switch (shape.type) {
      case 'diamond':
        shapeContent = CustomPaint(
          painter: _DiamondPainter(
            color: Colors.white,
            borderColor: borderColor,
            strokeWidth: borderWidth,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Center(child: Text(text, textAlign: TextAlign.center, style: textStyle)),
          ),
        );
        break;
      default: // Rettangolo, cerchio, etc.
        shapeContent = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(shape.type == 'circle' ? 999 : 8),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: isSelected ? theme.colorScheme.primary.withAlpha(76) : Colors.black12,
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

    // L'AnimatedContainer fornisce una transizione fluida quando cambiano le proprietà (es. selezione)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: shapeContent,
    );
  }
}

// --- COMPONENTI DI SUPPORTO E PAINTER ---

/// [_EmptyCanvasPlaceholder] mostrato quando la tela è vuota.
class _EmptyCanvasPlaceholder extends StatelessWidget {
  const _EmptyCanvasPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Crea una forma dalla barra in alto per iniziare",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}


/// [_GridPainter] disegna una griglia con linee maggiori e minori.
class _GridPainter extends CustomPainter {
  final Color minorColor;
  final Color majorColor;
  final double spacing;
  final double minorWidth;
  final double majorWidth;
  final int majorEvery;

  _GridPainter({
    required this.minorColor,
    required this.majorColor,
    this.spacing = 24,
    this.minorWidth = 1.0,
    this.majorWidth = 1.6,
    this.majorEvery = 4,
  });

  // Factory constructor per creare il painter direttamente dal tema
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
    final minor = Paint()
      ..color = minorColor
      ..strokeWidth = minorWidth;
    final major = Paint()
      ..color = majorColor
      ..strokeWidth = majorWidth;

    int i = 0;
    for (double x = 0; x <= size.width + 0.5; x += spacing, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (i % majorEvery == 0) ? major : minor);
    }
    i = 0;
    for (double y = 0; y <= size.height + 0.5; y += spacing, i++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (i % majorEvery == 0) ? major : minor);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) {
    return old.minorColor != minorColor ||
        old.majorColor != majorColor ||
        old.spacing != spacing ||
        old.minorWidth != minorWidth ||
        old.majorWidth != majorWidth ||
        old.majorEvery != majorEvery;
  }
}

/// [_DiamondPainter] disegna una forma a rombo.
class _DiamondPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double strokeWidth;

  _DiamondPainter({required this.color, required this.borderColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// Invece di usare withOpacity, ho usato withAlpha per compatibilità con la tua versione
// ma ti suggerisco di rimuovere la seguente estensione e usare .withOpacity() che è standard.
extension ColorAlpha on Color {
  Color withValues({int? alpha}) {
    return withAlpha(alpha ?? this.alpha);
  }
}