import 'dart:math';
import 'package:flutter/material.dart';

// Rimuovo l'uso del Bloc per la preview: usiamo direttamente gli stessi painter della workarea
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../user_dashboard/project_workspace/views/painters.dart';

/// Preview statica di un flowchart (solo visualizzazione) che:
/// - Effettua il parse del JSON con FlowchartLoaded.fromJson
/// - Scala tutto il contenuto (forme + connessioni) per entrare nell'area disponibile
/// - Usa gli stessi painter di connessioni e diamond della workarea così da avere label true/false
/// - Non permette interazioni / selezioni / drag
class FlowchartPreview extends StatelessWidget {
  final String flowchartContent;
  final bool showGrid;
  final bool emphasizeBorders;
  final bool showUnsavedBadge;

  const FlowchartPreview({
    super.key,
    required this.flowchartContent,
    this.showGrid = true,
    this.emphasizeBorders = true,
    this.showUnsavedBadge = false,
  });

  FlowchartLoaded _parse(String raw) {
    if (raw.trim().isEmpty) return const FlowchartLoaded();
    try {
      return FlowchartLoaded.fromJson(raw);
    } catch (e) {
      debugPrint('FlowchartPreview parse error: $e');
      return const FlowchartLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _parse(flowchartContent);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final borderColor = emphasizeBorders
        ? primary.withAlpha((0.85 * 255).round())
        : theme.dividerColor;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface, // rimosso gradient (niente sfumato)
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: emphasizeBorders ? 3 : 1.2,
          ),
          boxShadow: emphasizeBorders
              ? [
                  BoxShadow(
                    color: primary.withAlpha((0.18 * 255).round()),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: primary.withAlpha((0.10 * 255).round()),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.05 * 255).round()),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            _StaticFlowchartViewport(
              shapes: state.shapes,
              connections: state.connections,
              showGrid: showGrid,
              emphasized: emphasizeBorders,
            ),
            if (emphasizeBorders)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.35 * 255).round()),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            if (showUnsavedBadge)
              Positioned(
                top: 8,
                left: 10,
                child: _UnsavedBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnsavedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.errorContainer.withAlpha((0.90 * 255).round());
    final txt = theme.colorScheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withAlpha((0.5 * 255).round()), width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.error.withAlpha((0.22 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: txt),
          const SizedBox(width: 6),
          Text(
            'Versione non salvata',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: txt,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticFlowchartViewport extends StatelessWidget {
  final List<FlowchartShape> shapes;
  final List<FlowchartConnection> connections;
  final bool showGrid;
  final bool emphasized;

  const _StaticFlowchartViewport({
    required this.shapes,
    required this.connections,
    required this.showGrid,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    if (shapes.isEmpty) {
      return Stack(
        children: [
          if (showGrid) Positioned.fill(child: CustomPaint(painter: _previewGrid(context, emphasized))),
          Center(
            child: Text(
              'Diagramma Vuoto',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      );
    }

    // Calcola bounding box del contenuto
    Rect? bounds;
    for (final s in shapes) {
      final w = (s.width <= 0) ? 100.0 : s.width;
      final h = (s.height <= 0) ? 60.0 : s.height;
      final r = Rect.fromLTWH(s.x, s.y, w, h);
      bounds = bounds == null ? r : bounds.expandToInclude(r);
    }
    bounds ??= const Rect.fromLTWH(0, 0, 100, 60);

    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 20.0;
        final availW = max(10.0, constraints.maxWidth - padding * 2);
        final availH = max(10.0, constraints.maxHeight - padding * 2);
        final scaleX = availW / bounds!.width;
        final scaleY = availH / bounds.height;
        final scale = min(min(scaleX, scaleY), 1.0); // non ingrandiamo oltre 1:1

        final scaledContentW = bounds.width * scale;
        final scaledContentH = bounds.height * scale;
        final offsetX = (constraints.maxWidth - scaledContentW) / 2 - bounds.left * scale;
        final offsetY = (constraints.maxHeight - scaledContentH) / 2 - bounds.top * scale;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (showGrid)
              Positioned.fill(
                child: CustomPaint(painter: _previewGrid(context, emphasized)),
              ),
            // Applichiamo la stessa trasformazione a connessioni e forme
            Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: ConnectionPainter(
                            shapes: shapes,
                            connections: connections,
                            theme: Theme.of(context),
                          ),
                        ),
                      ),
                      for (final shape in shapes)
                        Positioned(
                          left: shape.x,
                          top: shape.y,
                          child: _StaticShape(shape: shape),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  GridPainter _previewGrid(BuildContext context, bool emphasized) {
    if (!emphasized) return GridPainter.fromTheme(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black;
    return GridPainter(
      minorColor: base.withAlpha(((isDark ? 0.22 : 0.16) * 255).round()),
      majorColor: base.withAlpha(((isDark ? 0.55 : 0.42) * 255).round()),
      spacing: 24,
      minorWidth: 1.1,
      majorWidth: 1.9,
      majorEvery: 4,
    );
  }
}

/// Versione statica del renderer forme che usa i tipi normalizzati
/// (condizione, start, fine, processo, input ...)
class _StaticShape extends StatelessWidget {
  final FlowchartShape shape;
  const _StaticShape({required this.shape});

  @override
  Widget build(BuildContext context) {
    final width = shape.width;
    final height = shape.height;
    final text = shape.text;

    final textStyle = const TextStyle(
      fontSize: 12,
      color: Colors.black87,
      fontWeight: FontWeight.w500,
    );

    final borderColor = Colors.blueGrey.shade400;
    const borderWidth = 1.5;

    switch (shape.type) {
      case 'condizione':
        return CustomPaint(
          painter: DiamondPainter(
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
      case 'input':
        return CustomPaint(
          painter: ParallelogramPainter(
            fillColor: Colors.white,
            borderColor: borderColor,
            strokeWidth: borderWidth,
            reversed: false,
            drawShadow: false,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: textStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      case 'output':
        return CustomPaint(
          painter: ParallelogramPainter(
            fillColor: Colors.white,
            borderColor: borderColor,
            strokeWidth: borderWidth,
            reversed: true,
            drawShadow: false,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: textStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      default:
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              (shape.type == 'start' || shape.type == 'fine') ? 999 : 8,
            ),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
  }
}