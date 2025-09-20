import 'package:equatable/equatable.dart';
import 'flowchart_state.dart';
import 'commands/flowchart_command.dart';

abstract class FlowchartEvent extends Equatable {
  const FlowchartEvent();
  @override
  List<Object?> get props => [];
}

class LoadFlowchart extends FlowchartEvent {
  final String jsonContent;
  const LoadFlowchart(this.jsonContent);
  @override
  List<Object?> get props => [jsonContent];
}

// CORREZIONE: L'evento ora accetta l'ID della forma di partenza per la connessione.
class AddShape extends FlowchartEvent {
  final FlowchartShape shape;
  final String? fromShapeId;

  const AddShape(this.shape, {this.fromShapeId});

  @override
  List<Object?> get props => [shape, fromShapeId];
}

class RemoveShape extends FlowchartEvent {
  final String shapeId;
  const RemoveShape(this.shapeId);
  @override
  List<Object?> get props => [shapeId];
}

class UpdateShape extends FlowchartEvent {
  final String shapeId;
  final double newX;
  final double newY;
  final double? oldX;
  final double? oldY;

  const UpdateShape({
    required this.shapeId,
    required this.newX,
    required this.newY,
    this.oldX,
    this.oldY,
  });
  @override
  List<Object?> get props => [shapeId, newX, newY, oldX, oldY];
}

class SelectShape extends FlowchartEvent {
  final String shapeId;
  const SelectShape(this.shapeId);
  @override
  List<Object?> get props => [shapeId];
}

class DeselectShape extends FlowchartEvent {}
class UndoCommand extends FlowchartEvent { const UndoCommand(); }
class RedoCommand extends FlowchartEvent { const RedoCommand(); }

class ExecuteCommand extends FlowchartEvent {
  final FlowchartCommand command;
  const ExecuteCommand(this.command);
  @override
  List<Object?> get props => [command];
}

class ResetFlowchart extends FlowchartEvent { const ResetFlowchart(); }
class ClearHistory extends FlowchartEvent { const ClearHistory(); }