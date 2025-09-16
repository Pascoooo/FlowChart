// lib/blocs/flowchart_bloc/flowchart_event.dart
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

class AddShape extends FlowchartEvent {
  final FlowchartShape shape;
  const AddShape(this.shape);

  @override
  List<Object?> get props => [shape];
}

class RemoveShape extends FlowchartEvent {
  final String shapeId;
  const RemoveShape(this.shapeId);

  @override
  List<Object?> get props => [shapeId];
}

// Evento modificato per supportare undo
class UpdateShape extends FlowchartEvent {
  final String shapeId;
  final double newX;
  final double newY;
  final double? oldX;  // Aggiunto per undo
  final double? oldY;  // Aggiunto per undo

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

// NUOVI EVENTI per undo/redo
class UndoCommand extends FlowchartEvent {
  const UndoCommand();
}

class RedoCommand extends FlowchartEvent {
  const RedoCommand();
}

// Evento generico per eseguire un comando
class ExecuteCommand extends FlowchartEvent {
  final FlowchartCommand command;
  const ExecuteCommand(this.command);

  @override
  List<Object?> get props => [command];
}

class ResetFlowchart extends FlowchartEvent {
  const ResetFlowchart();
}

// Evento per pulire la cronologia
class ClearHistory extends FlowchartEvent {
  const ClearHistory();
}