import '../flowchart_state.dart';

abstract class FlowchartCommand {
  FlowchartLoaded execute(FlowchartLoaded currentState);
  FlowchartLoaded undo(FlowchartLoaded currentState);
  String get description;
}

class AddShapeCommand implements FlowchartCommand {
  final FlowchartShape shape;

  AddShapeCommand(this.shape);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedShapes = List<FlowchartShape>.from(currentState.shapes)..add(shape);
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.where((s) => s.id != shape.id).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  String get description => 'Aggiungi ${shape.type}';
}

class RemoveShapeCommand implements FlowchartCommand {
  final FlowchartShape removedShape;

  RemoveShapeCommand(this.removedShape);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.where((s) => s.id != removedShape.id).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedShapes = List<FlowchartShape>.from(currentState.shapes)..add(removedShape);
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  String get description => 'Rimuovi ${removedShape.type}';
}

class MoveShapeCommand implements FlowchartCommand {
  final String shapeId;
  final double newX, newY, oldX, oldY;

  MoveShapeCommand({
    required this.shapeId,
    required this.newX,
    required this.newY,
    required this.oldX,
    required this.oldY
  });

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.map((s) {
      return s.id == shapeId ? s.copyWith(x: newX, y: newY) : s;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.map((s) {
      return s.id == shapeId ? s.copyWith(x: oldX, y: oldY) : s;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  String get description => 'Sposta forma';
}

// NUOVO: Comando per aggiornare proprietà delle forme
class UpdateShapePropertiesCommand implements FlowchartCommand {
  final String shapeId;
  final double? newWidth;
  final double? newHeight;
  final String? newText;
  final double? oldWidth;
  final double? oldHeight;
  final String? oldText;

  UpdateShapePropertiesCommand({
    required this.shapeId,
    this.newWidth,
    this.newHeight,
    this.newText,
    this.oldWidth,
    this.oldHeight,
    this.oldText,
  });

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.map((s) {
      return s.id == shapeId
          ? s.copyWith(
        width: newWidth,
        height: newHeight,
        text: newText,
      )
          : s;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.map((s) {
      return s.id == shapeId
          ? s.copyWith(
        width: oldWidth,
        height: oldHeight,
        text: oldText,
      )
          : s;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  String get description => 'Aggiorna proprietà forma';
}

class AddConnectionCommand implements FlowchartCommand {
  final FlowchartConnection connection;
  AddConnectionCommand(this.connection);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    // Validazione: evita connessioni duplicate
    if (currentState.connections.any((c) =>
    c.fromShapeId == connection.fromShapeId &&
        c.toShapeId == connection.toShapeId)) {
      return currentState; // Connessione già esistente
    }

    // Validazione: verifica che le forme esistano
    if (!currentState.shapes.any((s) => s.id == connection.fromShapeId) ||
        !currentState.shapes.any((s) => s.id == connection.toShapeId)) {
      return currentState; // Una o entrambe le forme non esistono
    }

    final updatedConnections = List<FlowchartConnection>.from(currentState.connections)..add(connection);
    return currentState.copyWith(connections: updatedConnections);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedConnections = currentState.connections.where((c) => c.id != connection.id).toList();
    return currentState.copyWith(connections: updatedConnections);
  }

  @override
  String get description => 'Aggiungi connessione';
}

class RemoveConnectionCommand implements FlowchartCommand {
  final FlowchartConnection connection;
  RemoveConnectionCommand(this.connection);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedConnections = currentState.connections.where((c) => c.id != connection.id).toList();
    return currentState.copyWith(connections: updatedConnections);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedConnections = List<FlowchartConnection>.from(currentState.connections)..add(connection);
    return currentState.copyWith(connections: updatedConnections);
  }

  @override
  String get description => 'Rimuovi connessione';
}

class CompositeCommand implements FlowchartCommand {
  final List<FlowchartCommand> commands;
  final String _description;

  CompositeCommand(this.commands, this._description);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    return commands.fold(currentState, (state, command) => command.execute(state));
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    return commands.reversed.fold(currentState, (state, command) => command.undo(state));
  }

  @override
  String get description => _description;
}