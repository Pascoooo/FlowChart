import 'dart:ui';

import 'package:uuid/uuid.dart';

import 'flowchart_state.dart';

/// Definisce i tipi di forma logici e centralizzati.
/// Questo enum è la "fonte di verità" per i tipi di forme.
enum ShapeType {
  start,
  input,
  output,
  processo,
  condizione,
  fine,
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
          type: 'start',
          x: position.dx,
          y: position.dy,
          width: 90.0,
          height: 90.0,
          text: 'Start',
        );
      case ShapeType.fine:
        return FlowchartShape(
          id: 'fine_${_uuid.v4()}',
          type: 'fine',
          x: position.dx,
          y: position.dy,
          width: 90.0,
          height: 90.0,
          text: 'end',
        );
      case ShapeType.input:
        return FlowchartShape(
          id: _uuid.v4(),
          type: 'input',
          x: position.dx,
          y: position.dy,
          width: 130.0,
            height: 60.0,
          text: 'input',
        );
      case ShapeType.output:
        return FlowchartShape(
          id: _uuid.v4(),
          type: 'output',
          x: position.dx,
          y: position.dy,
          width: 130.0,
          height: 60.0,
          text: 'output',
        );
      case ShapeType.processo:
        return FlowchartShape(
          id: _uuid.v4(),
          type: 'processo',
          x: position.dx,
          y: position.dy,
          width: 150.0,
          height: 60.0,
          text: 'processo',
        );
      case ShapeType.condizione:
        return FlowchartShape(
          id: _uuid.v4(),
          type: 'condizione',
          x: position.dx,
          y: position.dy,
          width: 120.0,
          height: 80.0,
          text: 'condizione',
        );
    }
  }
}