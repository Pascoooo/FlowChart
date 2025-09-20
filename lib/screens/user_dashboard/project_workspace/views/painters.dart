import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';

// GridPainter e DiamondPainter rimangono invariati

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

/// Painter for drawing connections between shapes.
class ConnectionPainter extends CustomPainter {
  final List<FlowchartShape> shapes;
  final List<FlowchartConnection> connections;
  final ThemeData theme;

  ConnectionPainter({
    required this.shapes,
    required this.connections,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.colorScheme.onSurface.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final shapeMap = {for (var shape in shapes) shape.id: shape};

    for (final connection in connections) {
      final fromShape = shapeMap[connection.fromShapeId];
      final toShape = shapeMap[connection.toShapeId];

      if (fromShape != null && toShape != null) {
        final startPoint = Offset(
          fromShape.x + fromShape.width / 2,
          fromShape.y + fromShape.height / 2,
        );
        final endPoint = Offset(
          toShape.x + toShape.width / 2,
          toShape.y + toShape.height / 2,
        );

        // Calcola il punto di fine sul perimetro della forma di destinazione
        final endPointOnPerimeter = _getIntersectionPoint(startPoint, endPoint, toShape);

        canvas.drawLine(startPoint, endPointOnPerimeter, paint);

        // Disegna la freccia nel nuovo punto di fine
        _drawArrow(canvas, paint, startPoint, endPointOnPerimeter);
      }
    }
  }

  /// Calcola il punto di intersezione tra la linea (dal centro di fromShape al centro di toShape)
  /// e il perimetro di toShape.
  Offset _getIntersectionPoint(Offset startPoint, Offset endPoint, FlowchartShape toShape) {
    final dx = endPoint.dx - startPoint.dx;
    final dy = endPoint.dy - startPoint.dy;

    if (dx == 0 && dy == 0) return endPoint;

    final angle = atan2(dy, dx);
    double radiusX, radiusY;

    // Approssimazione per forme non circolari
    radiusX = toShape.width / 2;
    radiusY = toShape.height / 2;

    final cosAngle = cos(angle);
    final sinAngle = sin(angle);

    // Calcolo basato su un'ellisse inscritta nel rettangolo della forma
    final intersectX = endPoint.dx - (radiusX * cosAngle);
    final intersectY = endPoint.dy - (radiusY * sinAngle);

    // Per il diamante, l'approssimazione ellittica è abbastanza buona
    // Per un rettangolo, potremmo fare un calcolo più preciso, ma questo è un buon inizio.
    final finalPoint = Offset(intersectX, intersectY);

    // Evita che la freccia sia troppo interna per forme molto rettangolari
    if (toShape.type == 'rectangle') {
      final borderX = toShape.x + (dx > 0 ? 0 : toShape.width);
      final borderY = toShape.y + (dy > 0 ? 0 : toShape.height);
      if ((finalPoint.dx > toShape.x && finalPoint.dx < toShape.x + toShape.width) &&
          (finalPoint.dy > toShape.y && finalPoint.dy < toShape.y + toShape.height)) {
        return finalPoint;
      }
    }

    return finalPoint;
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
      old.shapes != shapes || old.connections != connections;
}