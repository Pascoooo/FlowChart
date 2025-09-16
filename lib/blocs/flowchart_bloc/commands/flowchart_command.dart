// lib/blocs/flowchart_bloc/commands/flowchart_command.dart
import '../flowchart_state.dart';

/// Interfaccia base per tutti i comandi che possono essere annullati
abstract class FlowchartCommand {
  /// Esegue il comando e restituisce il nuovo stato
  FlowchartLoaded execute(FlowchartLoaded currentState);

  /// Annulla il comando e restituisce lo stato precedente
  FlowchartLoaded undo(FlowchartLoaded currentState);

  /// Descrizione del comando per debug/UI
  String get description;
}

/// Comando per aggiungere una forma
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
    final newSelectedId = currentState.selectedShapeId == shape.id ? null : currentState.selectedShapeId;
    return currentState.copyWith(
      shapes: updatedShapes,
      selectedShapeId: newSelectedId,
    );
  }

  @override
  String get description => 'Aggiungi ${shape.type}';
}

/// Comando per rimuovere una forma
class RemoveShapeCommand implements FlowchartCommand {
  final FlowchartShape removedShape;
  final String? previousSelectedId;

  RemoveShapeCommand(this.removedShape, this.previousSelectedId);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.where((s) => s.id != removedShape.id).toList();
    final newSelectedId = currentState.selectedShapeId == removedShape.id ? null : currentState.selectedShapeId;
    return currentState.copyWith(
      shapes: updatedShapes,
      selectedShapeId: newSelectedId,
    );
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedShapes = List<FlowchartShape>.from(currentState.shapes)..add(removedShape);
    return currentState.copyWith(
      shapes: updatedShapes,
      selectedShapeId: previousSelectedId,
    );
  }

  @override
  String get description => 'Rimuovi ${removedShape.type}';
}

/// Comando per spostare una forma
class MoveShapeCommand implements FlowchartCommand {
  final String shapeId;
  final double newX;
  final double newY;
  final double oldX;
  final double oldY;

  MoveShapeCommand({
    required this.shapeId,
    required this.newX,
    required this.newY,
    required this.oldX,
    required this.oldY,
  });

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.map((shape) {
      if (shape.id == shapeId) {
        return shape.copyWith(x: newX, y: newY);
      }
      return shape;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedShapes = currentState.shapes.map((shape) {
      if (shape.id == shapeId) {
        return shape.copyWith(x: oldX, y: oldY);
      }
      return shape;
    }).toList();
    return currentState.copyWith(shapes: updatedShapes);
  }

  @override
  String get description => 'Sposta forma';
}

/// Comando composito per operazioni multiple
class CompositeCommand implements FlowchartCommand {
  final List<FlowchartCommand> commands;
  final String _description;

  CompositeCommand(this.commands, this._description);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    FlowchartLoaded state = currentState;
    for (final command in commands) {
      state = command.execute(state);
    }
    return state;
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    FlowchartLoaded state = currentState;
    for (final command in commands.reversed) {
      state = command.undo(state);
    }
    return state;
  }

  @override
  String get description => _description;
}