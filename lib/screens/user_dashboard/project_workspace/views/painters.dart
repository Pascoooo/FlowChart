import 'dart:math';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';

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
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GridPainter(
      minorColor: (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.14 : 0.10),
      majorColor: (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.30 : 0.18),
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
      old.color != color ||
          old.borderColor != borderColor ||
          old.strokeWidth != strokeWidth;
}

class ConnectionPainter extends CustomPainter {
  final List<FlowNode> nodes;
  final List<FlowchartEdge> edges;
  final FluentThemeData theme;

  ConnectionPainter({
    required this.nodes,
    required this.edges,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (theme.typography.body?.color ?? Colors.black).withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final nodeMap = {for (var node in nodes) node.id: node};

    for (final edge in edges) {
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];

      if (fromNode != null && toNode != null) {
        Offset startPoint;

        // Gestione dei nodi ciclo (while e do-while)
        if ((fromNode.kind == FlowNodeKind.whileLoop || fromNode.kind == FlowNodeKind.doWhileLoop) && edge.port != null) {
          if (edge.port == 'true') {
            startPoint = Offset(
                fromNode.x + fromNode.width / 2, fromNode.y + fromNode.height);
          } else if (edge.port == 'doWhileStart') {
            startPoint = Offset(
                fromNode.x + fromNode.width / 2, fromNode.y + fromNode.height);
          } else if (edge.port == 'false') {
            startPoint = Offset(
                fromNode.x + fromNode.width, fromNode.y + fromNode.height / 2);
          } else if (edge.port == 'loop') {
            startPoint = Offset(
                fromNode.x + fromNode.width / 2, fromNode.y + fromNode.height);
          } else {
            startPoint = Offset(
                fromNode.x + fromNode.width / 2, fromNode.y + fromNode.height);
          }
        }
        // Gestione dei nodi decision (condizioni)
        else if (fromNode.kind == FlowNodeKind.decision && edge.port != null) {
          if (edge.port == 'true') {
            startPoint = Offset(
                fromNode.x + fromNode.width, fromNode.y + fromNode.height / 2);
          } else {
            startPoint = Offset(fromNode.x, fromNode.y + fromNode.height / 2);
          }
        } else {
          startPoint = Offset(
              fromNode.x + fromNode.width / 2, fromNode.y + fromNode.height);
        }

        // Gestione del punto di arrivo per archi di ritorno
        Offset endPoint;
        if (edge.port == 'loop') {
          endPoint = Offset(toNode.x, toNode.y + toNode.height / 2);
        } else {
          final endCenter =
              Offset(toNode.x + toNode.width / 2, toNode.y + toNode.height / 2);
          endPoint = _getIntersectionPointWithRect(startPoint, endCenter, toNode);
        }

        // ✨ NUOVO: per gli archi di chiusura ciclo ('loop') disegna una L dal centro del blocco alla punta sinistra del rombo
        if (edge.port == 'loop' && (toNode.kind == FlowNodeKind.whileLoop || toNode.kind == FlowNodeKind.doWhileLoop)) {
          // Partenza dal centro del blocco finale
          final startCenter = Offset(
              fromNode.x + fromNode.width / 2, fromNode.y + fromNode.height / 2);
          // Punta sinistra del rombo del ciclo
          final leftTip = Offset(toNode.x, toNode.y + toNode.height / 2);
          // Clearance verso sinistra per instradare la L senza sovrapporsi
          const clearance = 24.0;
          final viaX = min(startCenter.dx, leftTip.dx) - clearance;
          final points = <Offset>[
            startCenter,
            Offset(viaX, startCenter.dy), // orizzontale verso sinistra dalla metà del blocco
            Offset(viaX, leftTip.dy),     // verticale fino all'altezza della punta sinistra del rombo
            leftTip,                      // entra nella punta sinistra del rombo
          ];
          _drawOrthogonalArrow(canvas, paint, points);
        }
        // ✨ per il do-while ramo 'true' disegna un percorso ortogonale sul lato sinistro
        else if (fromNode.kind == FlowNodeKind.doWhileLoop && (edge.port == 'true' || edge.port == 'doWhileStart')) {
          // Spigolo sinistro del rombo do-while
          final startLeft = Offset(fromNode.x, fromNode.y + fromNode.height / 2);
          // Lato sinistro del blocco di inizio corpo
          final endLeft = Offset(toNode.x, toNode.y + toNode.height / 2);
          // Clearance verso sinistra
          final clearance = 24.0;
          final viaX = min(startLeft.dx, endLeft.dx) - clearance;
          final points = <Offset>[
            startLeft,
            Offset(viaX, startLeft.dy),   // vai a sinistra dallo spigolo del rombo
            Offset(viaX, endLeft.dy),     // su/giù fino all'altezza del target
            endLeft,                       // entra da sinistra nel blocco di inizio
          ];
          _drawOrthogonalArrow(canvas, paint, points);
        } else {
          // default: linea diretta
          canvas.drawLine(startPoint, endPoint, paint);
          _drawArrow(canvas, paint, startPoint, endPoint);
        }

        // Disegna le etichette per i rami
        if (fromNode.kind == FlowNodeKind.decision && edge.port != null) {
          _drawBranchLabel(canvas, fromNode, edge.port!);
        } else if ((fromNode.kind == FlowNodeKind.whileLoop ||
                    fromNode.kind == FlowNodeKind.doWhileLoop) && edge.port != null) {
          _drawLoopLabel(canvas, fromNode, edge.port!);
        }
      }
    }
  }

  void _drawOrthogonalArrow(Canvas canvas, Paint paint, List<Offset> points) {
    // Disegna segmenti rettilinei 90°
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
    // Freccia sull'ultimo segmento
    final start = points[points.length - 2];
    final end = points.last;
    _drawArrow(canvas, paint, start, end);
  }

  Offset _getIntersectionPointWithRect(
      Offset startPoint, Offset endCenter, FlowNode toNode) {
    final toRect =
    Rect.fromLTWH(toNode.x, toNode.y, toNode.width, toNode.height);
    final line = Line(endCenter, startPoint);

    Offset? topIntersection =
    line.intersection(Line(toRect.topLeft, toRect.topRight));
    Offset? rightIntersection =
    line.intersection(Line(toRect.topRight, toRect.bottomRight));
    Offset? bottomIntersection =
    line.intersection(Line(toRect.bottomRight, toRect.bottomLeft));
    Offset? leftIntersection =
    line.intersection(Line(toRect.bottomLeft, toRect.topLeft));

    final intersections = [
      topIntersection,
      rightIntersection,
      bottomIntersection,
      leftIntersection
    ].where((p) => p != null).cast<Offset>().toList();

    if (intersections.isEmpty) return endCenter;

    intersections.sort(
            (a, b) => (a - startPoint).distance.compareTo((b - startPoint).distance));
    return intersections.first;
  }

  void _drawArrow(
      Canvas canvas, Paint paint, Offset startPoint, Offset endPoint) {
    final angle =
    atan2(endPoint.dy - startPoint.dy, endPoint.dx - startPoint.dx);
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

  void _drawBranchLabel(Canvas canvas, FlowNode fromNode, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label == 'true' ? 'True' : 'False',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: theme.typography.body?.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padding = 6.0;
    const offsetFromNode = 12.0;
    late Offset labelPos;

    if (label == 'true') {
      labelPos = Offset(
        fromNode.x + fromNode.width + offsetFromNode,
        fromNode.y + fromNode.height / 2 - (textPainter.height / 2),
      );
    } else {
      labelPos = Offset(
        fromNode.x - textPainter.width - (padding * 2) - offsetFromNode,
        fromNode.y + fromNode.height / 2 - (textPainter.height / 2),
      );
    }

    final rect = Rect.fromLTWH(
      labelPos.dx,
      labelPos.dy,
      textPainter.width + padding * 2,
      textPainter.height + padding * 2,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(99));
    final bgPaint = Paint()..color = theme.cardColor.withAlpha(240);
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.inactiveColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    textPainter.paint(
      canvas,
      Offset(rect.left + padding, rect.top + padding),
    );
  }

  void _drawLoopLabel(Canvas canvas, FlowNode fromNode, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Loop',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: theme.typography.body?.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padding = 6.0;
    // const offsetFromNode = 12.0; // rimosso: non usato
    Offset labelPos;

    // Posiziona l'etichetta sopra il nodo per l'arco di ritorno
    labelPos = Offset(
      fromNode.x + fromNode.width / 2 - textPainter.width / 2,
      fromNode.y - textPainter.height - padding,
    );

    final rect = Rect.fromLTWH(
      labelPos.dx,
      labelPos.dy,
      textPainter.width + padding * 2,
      textPainter.height + padding * 2,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(99));
    final bgPaint = Paint()..color = theme.cardColor.withAlpha(240);
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.inactiveColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    textPainter.paint(
      canvas,
      Offset(rect.left + padding, rect.top + padding),
    );
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter old) =>
      old.nodes != nodes || old.edges != edges || old.theme != theme;
}

class Line {
  final Offset p1, p2;
  Line(this.p1, this.p2);

  Offset? intersection(Line other) {
    final x1 = p1.dx, y1 = p1.dy;
    final x2 = p2.dx, y2 = p2.dy;
    final x3 = other.p1.dx, y3 = other.p1.dy;
    final x4 = other.p2.dx, y4 = other.p2.dy;

    final den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (den == 0) return null;

    final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den;
    final u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den;

    if (t > 0 && t <= 1 && u >= 0 && u <= 1) {
      return Offset(x1 + t * (x2 - x1), y1 + t * (y2 - y1));
    }
    return null;
  }
}

class ParallelogramPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double strokeWidth;
  final bool reversed;

  ParallelogramPainter({
    required this.fillColor,
    required this.borderColor,
    required this.strokeWidth,
    this.reversed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final slant = size.width * 0.2;
    final path = Path();

    if (!reversed) {
      path
        ..moveTo(slant, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width - slant, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width - slant, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(slant, size.height)
        ..close();
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
          old.reversed != reversed;
}

// ⚠️ NUOVO: Painter per il bordo di selezione che segue la forma esatta del nodo
class NodeSelectionBorderPainter extends CustomPainter {
  final FlowNodeKind nodeKind;
  final Color borderColor;
  final double strokeWidth;

  NodeSelectionBorderPainter({
    required this.nodeKind,
    required this.borderColor,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint per il bordo (SOLO BORDO, niente riempimento)
    final strokePaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    switch (nodeKind) {
      case FlowNodeKind.start:
      case FlowNodeKind.end:
        // Cerchio
        final center = Offset(size.width / 2, size.height / 2);
        final radius = size.width / 2;
        canvas.drawCircle(center, radius, strokePaint);
        break;

      case FlowNodeKind.decision:
        // Rombo
        final path = Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(0, size.height / 2)
          ..close();
        canvas.drawPath(path, strokePaint);
        break;

      case FlowNodeKind.input:
        // Parallelogramma (non invertito)
        final slant = size.width * 0.2;
        final path = Path()
          ..moveTo(slant, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width - slant, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path, strokePaint);
        break;

      case FlowNodeKind.output:
        // Parallelogramma (invertito)
        final slant = size.width * 0.2;
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(size.width - slant, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(slant, size.height)
          ..close();
        canvas.drawPath(path, strokePaint);
        break;

      default:
        // Rettangolo arrotondato per process, assignment, ecc.
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(8),
        );
        canvas.drawRRect(rect, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant NodeSelectionBorderPainter old) =>
      old.nodeKind != nodeKind ||
      old.borderColor != borderColor ||
      old.strokeWidth != strokeWidth;
}
