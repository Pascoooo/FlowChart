import 'dart:math';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';

// GridPainter, DiamondPainter, e ParallelogramPainter non necessitano di modifiche
// in quanto non dipendono direttamente dai modelli di dati del flowchart.
// Li includo qui per completezza del file.

class GridPainter extends CustomPainter {
  final Color minorColor, majorColor;
  final double spacing, minorWidth, majorWidth;
  final int majorEvery;

  GridPainter({
    required this.minorColor,
    required this.majorColor,
    this.spacing = 24,
    this.minorWidth = 1.0,
    this.majorWidth = 1.6,
    this.majorEvery = 4,
  });

  factory GridPainter.fromTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GridPainter(
      minorColor: (isDark ? Colors.white : Colors.black)
          .withOpacity(isDark ? 0.14 : 0.10),
      majorColor: (isDark ? Colors.white : Colors.black)
          .withOpacity(isDark ? 0.30 : 0.18),
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

    for (int i = 0; i * spacing <= size.width; i++) {
      final x = i * spacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          (i % majorEvery == 0) ? major : minor);
    }
    for (int i = 0; i * spacing <= size.height; i++) {
      final y = i * spacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          (i % majorEvery == 0) ? major : minor);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter old) =>
      old.minorColor != minorColor || old.majorColor != majorColor;
}

class DiamondPainter extends CustomPainter {
  final Color color, borderColor;
  final double strokeWidth;

  DiamondPainter({
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

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant DiamondPainter old) =>
      old.color != color || old.borderColor != borderColor || old.strokeWidth != strokeWidth;
}

/// Painter per disegnare le connessioni tra i nodi.
class ConnectionPainter extends CustomPainter {
  // Utilizza i nuovi modelli
  final List<FlowNode> nodes;
  final List<FlowchartEdge> edges;
  final ThemeData theme;

  ConnectionPainter({
    required this.nodes,
    required this.edges,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.colorScheme.onSurface.withAlpha((0.5 * 255).round())
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // La mappa ora contiene FlowNode
    final nodeMap = {for (var node in nodes) node.id: node};

    for (final edge in edges) {
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];

      if (fromNode != null && toNode != null) {
        Offset startPoint;
        // La logica ora usa FlowNodeKind
        if (fromNode.kind == FlowNodeKind.decision && edge.port != null) {
          if (edge.port == 'true') {
            startPoint = Offset(fromNode.x + fromNode.width, fromNode.y + fromNode.height / 2);
          } else { // 'false'
            startPoint = Offset(fromNode.x, fromNode.y + fromNode.height / 2);
          }
        } else {
          startPoint = Offset(
            fromNode.x + fromNode.width / 2,
            fromNode.y + fromNode.height / 2,
          );
        }

        final endCenter = Offset(
          toNode.x + toNode.width / 2,
          toNode.y + toNode.height / 2,
        );
        // La funzione helper ora accetta FlowNode
        final endPointOnPerimeter = _getIntersectionPoint(startPoint, endCenter, toNode);

        canvas.drawLine(startPoint, endPointOnPerimeter, paint);
        _drawArrow(canvas, paint, startPoint, endPointOnPerimeter);

        // Disegna etichetta true/false se applicabile
        if (fromNode.kind == FlowNodeKind.decision && edge.port != null) {
          final label = edge.port!;
          final textPainter = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          const padding = 4.0;
          late Rect rect;
          if (label == 'true') {
            final dx = fromNode.x + fromNode.width + 10;
            final dy = fromNode.y + fromNode.height / 2 - (textPainter.height / 2);
            rect = Rect.fromLTWH(
              dx,
              dy,
              textPainter.width + padding * 2,
              textPainter.height + padding * 2,
            );
          } else { // false
            final dx = fromNode.x - (textPainter.width + padding * 2) - 10;
            final dy = fromNode.y + fromNode.height / 2 - (textPainter.height / 2);
            rect = Rect.fromLTWH(
              dx,
              dy,
              textPainter.width + padding * 2,
              textPainter.height + padding * 2,
            );
          }

          final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
          final bgPaint = Paint()..color = theme.colorScheme.surface.withAlpha(230);
          canvas.drawRRect(rrect, bgPaint);
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = Colors.black.withAlpha(25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
          textPainter.paint(
            canvas,
            Offset(rect.left + padding, rect.top + padding),
          );
        }
      }
    }
  }

  /// Calcola il punto di intersezione. La logica interna non cambia, solo il tipo di parametro.
  Offset _getIntersectionPoint(Offset startPoint, Offset endPoint, FlowNode toNode) {
    final dx = endPoint.dx - startPoint.dx;
    final dy = endPoint.dy - startPoint.dy;

    if (dx == 0 && dy == 0) return endPoint;

    final angle = atan2(dy, dx);
    double radiusX = toNode.width / 2;
    double radiusY = toNode.height / 2;

    final cosAngle = cos(angle);
    final sinAngle = sin(angle);

    // Calcolo basato su un'ellisse inscritta nel rettangolo del nodo
    final intersectX = endPoint.dx - (radiusX * cosAngle);
    final intersectY = endPoint.dy - (radiusY * sinAngle);

    return Offset(intersectX, intersectY);
  }

  void _drawArrow(Canvas canvas, Paint paint, Offset startPoint, Offset endPoint) {
    final angle = atan2(endPoint.dy - startPoint.dy, endPoint.dx - startPoint.dx);
    const arrowSize = 10.0;
    const arrowAngle = pi / 6;

    final arrowPath = Path()
      ..moveTo(endPoint.dx - arrowSize * cos(angle - arrowAngle),
          endPoint.dy - arrowSize * sin(angle - arrowAngle))
      ..lineTo(endPoint.dx, endPoint.dy)
      ..lineTo(endPoint.dx - arrowSize * cos(angle + arrowAngle),
          endPoint.dy - arrowSize * sin(angle + arrowAngle));

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter old) =>
      old.nodes != nodes || old.edges != edges;
}

class ParallelogramPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double strokeWidth;
  final bool reversed;
  final bool drawShadow;

  ParallelogramPainter({
    required this.fillColor,
    required this.borderColor,
    required this.strokeWidth,
    this.reversed = false,
    this.drawShadow = false,
  });

  Path _buildPath(Size size) {
    final dx = size.width * 0.18; // inclinazione
    final path = Path();
    if (!reversed) {
      path
        ..moveTo(dx, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width - dx, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width - dx, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(dx, size.height)
        ..close();
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    if (drawShadow) {
      final shadowPaint = Paint()
        ..color = Colors.black.withAlpha(25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.save();
      canvas.translate(0, 2);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant ParallelogramPainter old) =>
      old.fillColor != fillColor ||
          old.borderColor != borderColor ||
          old.strokeWidth != strokeWidth ||
          old.reversed != reversed ||
          old.drawShadow != drawShadow;
}