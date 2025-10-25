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

  // Helper per ottenere il centro di un nodo (aggiunto per pulizia)
  Offset _getNodeCenter(FlowNode node) {
    return Offset(node.x + node.width / 2, node.y + node.height / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (theme.typography.body?.color ?? Colors.black).withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final nodeMap = {for (var node in nodes) node.id: node};


    // Raggruppa archi di chiusura ciclo per nodo ciclo di destinazione
    final Map<String, List<FlowchartEdge>> loopEdgesByTarget = {};
    for (final e in edges) {
      if (e.port == 'loop') {
        loopEdgesByTarget.putIfAbsent(e.to, () => []).add(e);
      }
    }

    // 1) Disegna tutti gli archi NON di chiusura ciclo normalmente
    for (final edge in edges) {
      if (edge.port == 'loop') continue; // gestiti dopo
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];
      if (fromNode == null || toNode == null) continue;

      // 💡 NUOVA GESTIONE SPECIALE per il corpo del Do-While
      if (fromNode.kind == FlowNodeKind.doWhileLoop && (edge.port == 'true' || edge.port == 'doWhileStart')) {
        final loopNode = fromNode;
        final bodyStartNode = toNode;

        // Il loop esce a sinistra del rombo e rientra a sinistra del nodo di inizio corpo
        final startPoint = Offset(loopNode.x, loopNode.y + loopNode.height / 2);
        final endPoint = Offset(bodyStartNode.x, bodyStartNode.y + bodyStartNode.height / 2);

        const double clearance = 36.0;
        // ✨ NUOVO: Calcola il livello di annidamento per evitare sovrapposizioni
        final nestingLevel = _getNestingLevel(loopNode, nodeMap, edges);
        // ✨ MODIFICATO: Usa la posizione del loopNode come riferimento stabile
        double viaX = loopNode.x - (clearance * (1.5 + nestingLevel));

        final points = [
            startPoint,
            Offset(viaX, startPoint.dy),
            Offset(viaX, endPoint.dy),
            endPoint,
        ];
        _drawOrthogonalArrow(canvas, paint, points);


        _drawLoopLabel(canvas, fromNode, edge.port!);
        continue;
      }

      // ✅ FIX: Calcola i centri di entrambi i nodi
      final startCenter = _getNodeCenter(fromNode);
      final endCenter = _getNodeCenter(toNode);

      Offset startPoint;

      // Logica per porte specifiche (Decisioni, Cicli)
      if ((fromNode.kind == FlowNodeKind.whileLoop || fromNode.kind == FlowNodeKind.doWhileLoop) && edge.port != null) {
        if (edge.port == 'true') {
          startPoint = Offset(fromNode.x + fromNode.width / 2, fromNode.y + fromNode.height);
        } else if (edge.port == 'doWhileStart') {
          startPoint = Offset(fromNode.x + fromNode.width / 2, fromNode.y + fromNode.height);
        } else if (edge.port == 'false') {
          startPoint = Offset(fromNode.x + fromNode.width, fromNode.y + fromNode.height / 2);
        } else {
          startPoint = _getIntersectionPoint(startCenter, endCenter, fromNode);
        }
      } else if (fromNode.kind == FlowNodeKind.decision && edge.port != null) {
        if (edge.port == 'true') {
          startPoint = Offset(fromNode.x + fromNode.width, fromNode.y + fromNode.height / 2);
        } else if (edge.port == 'false') {
          startPoint = Offset(fromNode.x, fromNode.y + fromNode.height / 2);
        } else {
          startPoint = _getIntersectionPoint(startCenter, endCenter, fromNode);
        }
      } else {
        // ✅ FIX: Applica la logica di intersezione dinamica a tutti gli altri nodi
        startPoint = _getIntersectionPoint(endCenter, startCenter, fromNode);
      }

      // ✅ FIX: Applica la logica di intersezione dinamica al nodo di destinazione
      Offset endPoint = _getIntersectionPoint(startCenter, endCenter, toNode);


      // default: linea diretta
      canvas.drawLine(startPoint, endPoint, paint);
      _drawArrow(canvas, paint, startPoint, endPoint);

      // Etichette
      if (fromNode.kind == FlowNodeKind.decision && edge.port != null) {
        _drawBranchLabel(canvas, fromNode, edge.port!);
      } else if ((fromNode.kind == FlowNodeKind.whileLoop || fromNode.kind == FlowNodeKind.doWhileLoop) && edge.port != null && edge.port != 'loop') {
        _drawLoopLabel(canvas, fromNode, edge.port!);
      }
    }

    // 2) Disegna archi di chiusura ciclo... (Questa sezione rimane invariata)
    for (final entry in loopEdgesByTarget.entries) {
      final loopNode = nodeMap[entry.key];
      if (loopNode == null) continue;
      final sources = entry.value.map((e) => nodeMap[e.from]).whereType<FlowNode>().toList();
      if (sources.isEmpty) continue;

      // Calcola i bottom-center dei nodi foglia
      final bottomCenters = sources
          .map((n) => Offset(n.x + n.width / 2, n.y + n.height))
          .toList();

      // Calcola tutti i nodi che appartengono al ciclo (corpo + rombo)
      final loopBodyIds = _collectLoopBodyNodeIds(loopNode, nodeMap, edges);
      final loopRects = <Rect>[
        for (final id in loopBodyIds)
          if (nodeMap[id] != null)
            Rect.fromLTWH(nodeMap[id]!.x, nodeMap[id]!.y, nodeMap[id]!.width, nodeMap[id]!.height),
        // Include sempre il rombo del ciclo
        Rect.fromLTWH(loopNode.x, loopNode.y, loopNode.width, loopNode.height),
      ];

      // Evita crash se loopRects è vuoto
      if (loopRects.isEmpty) continue;

      // ✨ NUOVO: Calcola il livello di annidamento per evitare sovrapposizioni
      final nestingLevel = _getNestingLevel(loopNode, nodeMap, edges);

      // Definisci un punto-ancora a sinistra del ciclo, alla media verticale dei bottomCenters
      final double baseClearance = 36.0;
      final double meanY = bottomCenters.map((o) => o.dy).reduce((a, b) => a + b) / bottomCenters.length;

      // ✨ MODIFICATO: viaX e anchorX sono basati sulla posizione del loopNode e sul livello di annidamento
      double viaX = loopNode.x - (baseClearance * (1.5 + nestingLevel));
      final double anchorY = meanY + 12.0;
      final Offset anchor = Offset(viaX + baseClearance / 2, anchorY);


      // Disegna convergenza: da ogni bottom-center al punto-ancora (solo linee, niente frecce)
      for (final start in bottomCenters) {
        final points = <Offset>[
          start,
          Offset(start.dx, anchor.dy), // verticale fino all'altezza dell'ancora
          anchor, // orizzontale verso l'ancora
        ];
        _drawOrthogonalPolyline(canvas, paint, points);
      }

      // Disegna il punto-ancora (UI-only)
      final anchorPaint = Paint()
        ..color = theme.accentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(anchor, 3.0, anchorPaint);

      // Traccia la L finale dall'ancora verso la punta sinistra del rombo del ciclo, senza toccare altri nodi del ciclo
      final leftTip = Offset(loopNode.x, loopNode.y + loopNode.height / 2);
      final pointsToLoop = <Offset>[
        anchor,
        Offset(viaX, anchor.dy),        // allontanati a sinistra
        Offset(viaX, leftTip.dy),       // sali/scendi fino alla metà del rombo
        leftTip,                        // entra nella punta sinistra
      ];
      _drawOrthogonalArrow(canvas, paint, pointsToLoop);

      // Etichetta "Loop" sopra il nodo di ciclo (una sola volta per gruppo)
      _drawLoopLabel(canvas, loopNode, 'loop');
    }
  }

  void _drawOrthogonalPolyline(Canvas canvas, Paint paint, List<Offset> points) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  void _drawOrthogonalArrow(Canvas canvas, Paint paint, List<Offset> points) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
    final start = points[points.length - 2];
    final end = points.last;
    _drawArrow(canvas, paint, start, end);
  }

  // --- 💡 NUOVA LOGICA DI INTERSEZIONE 💡 ---

  /// Funzione principale che smista al corretto helper di intersezione
  Offset _getIntersectionPoint(
      Offset lineStart, Offset lineEnd, FlowNode node) {

    final nodeCenter = _getNodeCenter(node);

    // Se la linea non ha lunghezza, ritorna il centro
    if ((lineStart - lineEnd).distance < 0.1) {
      return nodeCenter;
    }

    switch (node.kind) {
      case FlowNodeKind.decision:
      case FlowNodeKind.whileLoop:
      case FlowNodeKind.doWhileLoop:
        return _getIntersectionWithDiamond(lineStart, lineEnd, node);

      case FlowNodeKind.start:
      case FlowNodeKind.end:
      // Approssima come un cerchio
        return _getIntersectionWithCircle(lineStart, lineEnd, node);

      case FlowNodeKind.input:
        return _getIntersectionWithParallelogram(lineStart, lineEnd, node, reversed: false);

      case FlowNodeKind.output:
        return _getIntersectionWithParallelogram(lineStart, lineEnd, node, reversed: true);

      case FlowNodeKind.assignment:
      case FlowNodeKind.process:
      case FlowNodeKind.returnNode:
      default:
      // Tutti gli altri sono trattati come rettangoli
        return _getIntersectionWithRectangle(lineStart, lineEnd, node);
    }
  }

  /// Calcola l'intersezione con un Rettangolo
  Offset _getIntersectionWithRectangle(Offset lineStart, Offset lineEnd, FlowNode node) {
    final toRect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
    final line = Line(lineStart, lineEnd); // Usa la linea centro-centro

    final intersections = [
      line.intersection(Line(toRect.topLeft, toRect.topRight)),
      line.intersection(Line(toRect.topRight, toRect.bottomRight)),
      line.intersection(Line(toRect.bottomRight, toRect.bottomLeft)),
      line.intersection(Line(toRect.bottomLeft, toRect.topLeft)),
    ].whereType<Offset>().toList();

    if (intersections.isEmpty) return _getNodeCenter(node);

    // Ordina per distanza dal *punto di partenza* della linea
    intersections.sort(
            (a, b) => (a - lineStart).distance.compareTo((b - lineStart).distance));
    return intersections.first;
  }

  /// Calcola l'intersezione con un Rombo
  Offset _getIntersectionWithDiamond(Offset lineStart, Offset lineEnd, FlowNode node) {
    final top = Offset(node.x + node.width / 2, node.y);
    final right = Offset(node.x + node.width, node.y + node.height / 2);
    final bottom = Offset(node.x + node.width / 2, node.y + node.height);
    final left = Offset(node.x, node.y + node.height / 2);

    final line = Line(lineStart, lineEnd);

    final intersections = [
      line.intersection(Line(top, right)),
      line.intersection(Line(right, bottom)),
      line.intersection(Line(bottom, left)),
      line.intersection(Line(left, top)),
    ].whereType<Offset>().toList();

    if (intersections.isEmpty) return _getNodeCenter(node);

    intersections.sort(
            (a, b) => (a - lineStart).distance.compareTo((b - lineStart).distance));
    return intersections.first;
  }

  /// Calcola l'intersezione con un Parallelogramma
  Offset _getIntersectionWithParallelogram(Offset lineStart, Offset lineEnd, FlowNode node, {bool reversed = false}) {
    final slant = node.width * 0.2;
    late Offset p1, p2, p3, p4;

    if (!reversed) {
      p1 = Offset(node.x + slant, node.y); // top-left
      p2 = Offset(node.x + node.width, node.y); // top-right
      p3 = Offset(node.x + node.width - slant, node.y + node.height); // bottom-right
      p4 = Offset(node.x, node.y + node.height); // bottom-left
    } else {
      p1 = Offset(node.x, node.y); // top-left
      p2 = Offset(node.x + node.width - slant, node.y); // top-right
      p3 = Offset(node.x + node.width, node.y + node.height); // bottom-right
      p4 = Offset(node.x + slant, node.y + node.height); // bottom-left
    }

    final line = Line(lineStart, lineEnd);
    final intersections = [
      line.intersection(Line(p1, p2)),
      line.intersection(Line(p2, p3)),
      line.intersection(Line(p3, p4)),
      line.intersection(Line(p4, p1)),
    ].whereType<Offset>().toList();

    if (intersections.isEmpty) return _getNodeCenter(node);

    intersections.sort(
            (a, b) => (a - lineStart).distance.compareTo((b - lineStart).distance));
    return intersections.first;
  }

  /// Calcola l'intersezione con un Cerchio (approssimazione)
  /// Usa la linea dal centro e la scala al raggio
  Offset _getIntersectionWithCircle(Offset lineStart, Offset lineEnd, FlowNode node) {
    final center = _getNodeCenter(node);
    // Assumiamo che start/end siano cerchi, quindi raggio = larghezza/2
    final radius = node.width / 2;

    // Se i centri sono identici, non possiamo calcolare un vettore
    if ((lineStart - center).distance < 0.1) {
      // Questo accade quando si disegna un arco da un nodo a se stesso (non supportato)
      // O quando lineStart è il centro del nodo stesso
      // Restituiamo un punto qualsiasi sul bordo, es. top
      return Offset(center.dx, center.dy - radius);
    }

    // Vettore dal centro del nodo di partenza al centro di questo nodo
    // NOTA: lineEnd è il centro di *questo* nodo (il "toNode")
    //       lineStart è il centro del *altro* nodo (il "fromNode")
    final vec = lineEnd - lineStart;
    final dist = vec.distance;

    if (dist == 0) return center;

    // Trova il punto sul bordo del cerchio
    // (lineEnd è il centro, quindi ci spostiamo "indietro"
    // lungo il vettore per la lunghezza del raggio)
    return center - (vec / dist) * radius;
  }

  // --- Metodi Helper (disegno frecce, etichette) ---

  void _drawArrow(
      Canvas canvas, Paint paint, Offset startPoint, Offset endPoint) {

    // Evita di disegnare frecce se i punti sono coincidenti
    if ((startPoint - endPoint).distance < 1.0) return;

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
    late Offset textPaintPos;

    if (label == 'true') {
      labelPos = Offset(
        fromNode.x + fromNode.width + offsetFromNode,
        fromNode.y + fromNode.height / 2 - (textPainter.height / 2) - padding,
      );
    } else {
      labelPos = Offset(
        fromNode.x - textPainter.width - (padding * 2) - offsetFromNode,
        fromNode.y + fromNode.height / 2 - (textPainter.height / 2) - padding,
      );
    }

    textPaintPos = Offset(labelPos.dx + padding, labelPos.dy + padding);

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
      textPaintPos,
    );
  }

  void _drawLoopLabel(Canvas canvas, FlowNode fromNode, String label) {
    // Distingui tra etichetta 'true'/'false'/'doWhileStart' e 'loop'
    final String labelText;
    bool isLoopClosure = false;
    Offset labelPos;
    const padding = 6.0;

    if (label == 'loop') {
      labelText = 'Loop';
      isLoopClosure = true;
    } else if (label == 'true') {
      labelText = 'True';
    } else if (label == 'false') {
      labelText = 'False';
    } else if (label == 'doWhileStart') {
      labelText = 'Do';
    } else {
      labelText = label; // Fallback
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: theme.typography.body?.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const offsetFromNode = 12.0;
    late Offset textPaintPos;

    if (isLoopClosure) {
      // Posiziona l'etichetta "Loop" sopra il nodo per l'arco di ritorno
      labelPos = Offset(
        fromNode.x + fromNode.width / 2 - textPainter.width / 2 - padding,
        fromNode.y - textPainter.height - padding * 2,
      );
    } else if (label == 'false') {
      // Posiziona l'etichetta "False" a destra (per i cicli)
      labelPos = Offset(
        fromNode.x + fromNode.width + offsetFromNode,
        fromNode.y + fromNode.height / 2 - (textPainter.height / 2) - padding,
      );
    } else {
      // Posiziona "True" (while) o "Do" (do-while) sotto il nodo
      labelPos = Offset(
        fromNode.x + fromNode.width / 2 - textPainter.width / 2 - padding,
        fromNode.y + fromNode.height + padding,
      );
    }

    // L'offset per textPainter.paint è (rect.left + padding, rect.top + padding)
    textPaintPos = Offset(labelPos.dx + padding, labelPos.dy + padding);

    // Ricalcola il rect basandoti su labelPos (che è l'angolo top-left del *box*)
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
      textPaintPos,
    );
  }

  // Raccoglie gli ID dei nodi che fanno parte del corpo del ciclo (senza seguire archi 'loop')
  Set<String> _collectLoopBodyNodeIds(
    FlowNode loopNode,
    Map<String, FlowNode> nodeMap,
    List<FlowchartEdge> edges,
  ) {
    final body = <String>{};
    FlowchartEdge? startEdge;

    // Trova l'edge che inizia il corpo del ciclo
    if (loopNode.kind == FlowNodeKind.whileLoop) {
      startEdge = edges.firstWhere((e) => e.from == loopNode.id && e.port == 'true', orElse: () => const FlowchartEdge(from: '', to: ''));
    } else if (loopNode.kind == FlowNodeKind.doWhileLoop) {
      startEdge = edges.firstWhere((e) => e.from == loopNode.id && (e.port == 'true' || e.port == 'doWhileStart'), orElse: () => const FlowchartEdge(from: '', to: ''));
    }
    if (startEdge == null || startEdge.to.isEmpty) return body;

    final bodyStartNodeId = startEdge.to;
    final queue = <String>[bodyStartNodeId];
    final visited = <String>{bodyStartNodeId};

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      body.add(currentId);

      for (final edge in edges.where((e) => e.from == currentId)) {
        // Stop traversal if we exit the loop via the 'false' port of the loop header
        if (edge.from == loopNode.id && edge.port == 'false') {
          continue;
        }
        // Don't follow explicit 'loop' return edges of inner loops
        if (edge.port == 'loop') {
          continue;
        }

        if (!visited.contains(edge.to)) {
          visited.add(edge.to);
          queue.add(edge.to);
        }
      }
    }
    return body;
  }

  // ✨ NUOVA FUNZIONE HELPER per calcolare il livello di annidamento di un ciclo
  int _getNestingLevel(
    FlowNode loopNode,
    Map<String, FlowNode> nodeMap,
    List<FlowchartEdge> edges,
  ) {
    int level = 0;
    // Trova tutti gli altri cicli nel flowchart
    final otherLoops = nodeMap.values.where((n) =>
        (n.kind == FlowNodeKind.whileLoop || n.kind == FlowNodeKind.doWhileLoop) &&
        n.id != loopNode.id);

    for (final outerLoop in otherLoops) {
      // Controlla se il nostro loopNode è nel corpo di quest'altro ciclo
      final bodyIds = _collectLoopBodyNodeIds(outerLoop, nodeMap, edges);
      if (bodyIds.contains(loopNode.id)) {
        level++;
      }
    }
    return level;
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
      case FlowNodeKind.whileLoop:
      case FlowNodeKind.doWhileLoop:
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

class RoundedRectanglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double strokeWidth;
  final Radius radius;

  RoundedRectanglePainter({
    required this.color,
    required this.borderColor,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(rrect, Paint()..color = color);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant RoundedRectanglePainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}

class FunctionHeaderPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double strokeWidth;

  FunctionHeaderPainter({
    required this.fillColor,
    required this.borderColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    canvas.drawRRect(rrect, Paint()..color = fillColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    final sidePaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth;
    const padding = 8.0;
    canvas.drawLine(Offset(padding, 0), Offset(padding, size.height), sidePaint);
    canvas.drawLine(Offset(size.width - padding, 0),
        Offset(size.width - padding, size.height), sidePaint);
  }

  @override
  bool shouldRepaint(covariant FunctionHeaderPainter old) =>
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.strokeWidth != strokeWidth;
}

class ReturnPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double strokeWidth;

  ReturnPainter({
    required this.fillColor,
    required this.borderColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    canvas.drawRRect(rrect, Paint()..color = fillColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant ReturnPainter old) =>
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.strokeWidth != strokeWidth;
}

class NodeRenderer extends StatelessWidget {
  final FlowNode node;
  final bool isSelected;
  final bool isPreview;

  const NodeRenderer({
    super.key,
    required this.node,
    this.isSelected = false,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final String displayText = (node is FunctionHeaderNode)
        ? (node as FunctionHeaderNode).signatureText
        : node.text;

    final textStyle = isPreview
        ? theme.typography.caption?.copyWith(
            color: Colors.black.withValues(alpha: 0.85),
          )
        : TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: Colors.black,
          );

    final borderColor = isPreview
        ? theme.inactiveColor
        : (isSelected ? theme.accentColor : Colors.blue);
    final borderWidth = isPreview ? 1.5 : (isSelected ? 2.5 : 1.5);
    final fillColor = Colors.white;

    CustomPainter painter;

    switch (node.kind) {
      case FlowNodeKind.start:
      case FlowNodeKind.end:
        painter = RoundedRectanglePainter(
          color: fillColor,
          borderColor: borderColor,
          strokeWidth: borderWidth,
          radius: Radius.circular(min(node.width, node.height) / 2),
        );
        break;
      case FlowNodeKind.decision:
      case FlowNodeKind.whileLoop:
      case FlowNodeKind.doWhileLoop:
        painter = DiamondPainter(
          color: fillColor,
          borderColor: isPreview
              ? borderColor
              : (isSelected ? theme.accentColor : Colors.green),
          strokeWidth: borderWidth,
        );
        break;
      case FlowNodeKind.input:
      case FlowNodeKind.output:
        painter = ParallelogramPainter(
          fillColor: fillColor,
          borderColor: borderColor,
          strokeWidth: borderWidth,
          reversed: node.kind == FlowNodeKind.output,
        );
        break;
      case FlowNodeKind.functionHeader:
        painter = FunctionHeaderPainter(
          fillColor: fillColor,
          borderColor: borderColor,
          strokeWidth: borderWidth,
        );
        break;
      case FlowNodeKind.returnNode:
        painter = ReturnPainter(
          fillColor: fillColor,
          borderColor: borderColor,
          strokeWidth: borderWidth,
        );
        break;
      default: // Process, Assignment
        painter = RoundedRectanglePainter(
          color: fillColor,
          borderColor: borderColor,
          strokeWidth: borderWidth,
          radius: const Radius.circular(8),
        );
        break;
    }

    return Container(
      width: node.width,
      height: node.height,
      decoration: BoxDecoration(
        boxShadow: [
          // Rimosso l'effetto ombra per la selezione
          if (isPreview)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: CustomPaint(
        painter: painter,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              displayText,
              textAlign: TextAlign.center,
              style: textStyle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
