
import 'dart:ui';

import 'package:uuid/uuid.dart';

import 'flowchart_state.dart';

/// Definisce i tipi di forma logici e centralizzati.
/// Questo enum è la "fonte di verità" per i tipi di forme.
enum ShapeType {
  start,
  end,
  process,
  decision,
  inputOutput,
}
/// Una "fabbrica" centralizzata per creare ogni tipo di FlowchartShape.
/// Nasconde la complessità della creazione degli oggetti.
class FlowchartShapeFactory {
  static const _uuid = Uuid();

  static FlowchartShape createShape(ShapeType type, Offset position) {
    switch (type) {
      case ShapeType.start:
        return FlowchartShape(
          id: 'start_${_uuid.v4()}',
          type: 'start', // Il tipo logico per le regole
          x: position.dx,
          y: position.dy,
          width: 90.0,
          height: 90.0,
          text: 'Inizio',
        );
      case ShapeType.end:
        return FlowchartShape(
          id: 'end_${_uuid.v4()}',
          type: 'end', // Il tipo logico per le regole
          x: position.dx,
          y: position.dy,
          width: 90.0,
          height: 90.0,
          text: 'Fine',
        );
      case ShapeType.process:
        return FlowchartShape(
          id: _uuid.v4(),
          type: 'process',
          x: position.dx,
          y: position.dy,
          width: 120.0,
          height: 60.0,
          text: 'Processo',
        );
      case ShapeType.decision:
        return FlowchartShape(
          id: _uuid.v4(),
          type: 'decision',
          x: position.dx,
          y: position.dy,
          width: 120.0,
          height: 80.0,
          text: 'Decisione',
        );
      case ShapeType.inputOutput:
        return FlowchartShape(
          id: _uuid.v4(),
          type: 'input_output',
          x: position.dx,
          y: position.dy,
          width: 150.0, // Parallelogramma
          height: 60.0,
          text: 'Input/Output',
        );
    }
  }
}