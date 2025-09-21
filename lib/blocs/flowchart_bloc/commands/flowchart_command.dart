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

/// Comando potenziato per aggiornare le proprietà di una forma,
/// incluso testo E le liste di connessioni per mantenere la consistenza dei dati.
class UpdateShapePropertiesCommand implements FlowchartCommand {
  final String shapeId;
  final String? newText, oldText;
  final List<String>? newIncoming, oldIncoming;
  final List<String>? newOutgoing, oldOutgoing;

  // Costruttore principale per il testo
  UpdateShapePropertiesCommand({
    required this.shapeId,
    this.newText,
    this.oldText,
  }) : newIncoming = null, oldIncoming = null, newOutgoing = null, oldOutgoing = null;

  // Costruttore nominato per aggiornare solo le connessioni
  UpdateShapePropertiesCommand.connections({
    required this.shapeId,
    this.newIncoming, this.oldIncoming,
    this.newOutgoing, this.oldOutgoing,
  }) : newText = null, oldText = null;


  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.map((s) {
      if (s.id == shapeId) {
        return s.copyWith(
          text: newText ?? s.text,
          incomingConnectionIds: newIncoming ?? s.incomingConnectionIds,
          outgoingConnectionIds: newOutgoing ?? s.outgoingConnectionIds,
        );
      }
      return s;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.map((s) {
      if (s.id == shapeId) {
        return s.copyWith(
          text: oldText ?? s.text,
          incomingConnectionIds: oldIncoming ?? s.incomingConnectionIds,
          outgoingConnectionIds: oldOutgoing ?? s.outgoingConnectionIds,
        );
      }
      return s;
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
    final updatedConnections = List<FlowchartConnection>.from(currentState.connections)..add(connection);
    final updatedShapes = currentState.shapes.map((shape) {
      if (shape.id == connection.fromShapeId) {
        final newOutgoing = List<String>.from(shape.outgoingConnectionIds)..add(connection.id);
        return shape.copyWith(outgoingConnectionIds: newOutgoing);
      }
      if (shape.id == connection.toShapeId) {
        final newIncoming = List<String>.from(shape.incomingConnectionIds)..add(connection.id);
        return shape.copyWith(incomingConnectionIds: newIncoming);
      }
      return shape;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes, connections: updatedConnections);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedConnections = currentState.connections.where((c) => c.id != connection.id).toList();
    final updatedShapes = currentState.shapes.map((shape) {
      if (shape.id == connection.fromShapeId) {
        final newOutgoing = List<String>.from(shape.outgoingConnectionIds)..remove(connection.id);
        return shape.copyWith(outgoingConnectionIds: newOutgoing);
      }
      if (shape.id == connection.toShapeId) {
        final newIncoming = List<String>.from(shape.incomingConnectionIds)..remove(connection.id);
        return shape.copyWith(incomingConnectionIds: newIncoming);
      }
      return shape;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes, connections: updatedConnections);
  }

  @override
  String get description => 'Aggiungi connessione';
}

class RemoveConnectionCommand implements FlowchartCommand {
  final FlowchartConnection connection;
  RemoveConnectionCommand(this.connection);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    return AddConnectionCommand(connection).undo(currentState);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    return AddConnectionCommand(connection).execute(currentState);
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