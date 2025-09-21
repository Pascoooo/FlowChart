import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'FlowchartShapeFactory.dart';
import 'flowchart_state.dart';
import 'commands/flowchart_command.dart';

abstract class FlowchartEvent extends Equatable {
  const FlowchartEvent();
  @override
  List<Object?> get props => [];
}

class FlowchartActionFailure extends FlowchartState {
  final String title;
  final String message;

  const FlowchartActionFailure({required this.title, required this.message});

  @override
  List<Object?> get props => [title, message];
}


class LoadFlowchart extends FlowchartEvent {
  final String jsonContent;
  const LoadFlowchart(this.jsonContent);
  @override
  List<Object?> get props => [jsonContent];
}

class AddShape extends FlowchartEvent {
  final ShapeType shapeType;
  final String? fromShapeId;
  final String? fromPort; // 'true' | 'false' per decision, null altrimenti
  final BoxConstraints canvasConstraints;

  const AddShape({
      required this.shapeType,
      this.fromShapeId,
      this.fromPort,
      required this.canvasConstraints});

  @override
  List<Object?> get props => [shapeType, fromShapeId, fromPort];
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

// NUOVO: Evento per aggiornare proprietà delle forme
class UpdateShapeProperties extends FlowchartEvent {
  final String shapeId;
  final double? width;
  final double? height;
  final String? text;

  const UpdateShapeProperties({
    required this.shapeId,
    this.width,
    this.height,
    this.text,
  });

  @override
  List<Object?> get props => [shapeId, width, height, text];
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

class LinkToExistingEnd extends FlowchartEvent {
  final String fromShapeId;
  final String? fromPort; // per decisione left/right
  const LinkToExistingEnd({required this.fromShapeId, this.fromPort});
  @override
  List<Object?> get props => [fromShapeId, fromPort];
}
