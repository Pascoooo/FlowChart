// pascoooo/flowchart/FlowChart-rework/lib/blocs/flowchart_bloc/flowchart_event.dart
import 'package:equatable/equatable.dart';
import 'flowchart_state.dart';

abstract class FlowchartEvent extends Equatable {
  const FlowchartEvent();

  @override
  List<Object?> get props => [];
}

// --- NEW EVENT: To load data from a file ---
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

// --- NEW EVENT: To move or change a shape ---
class UpdateShape extends FlowchartEvent {
  final String shapeId;
  final double newX;
  final double newY;

  const UpdateShape({required this.shapeId, required this.newX, required this.newY});

  @override
  List<Object?> get props => [shapeId, newX, newY];
}

class SelectShape extends FlowchartEvent {
  final String shapeId;
  const SelectShape(this.shapeId);

  @override
  List<Object?> get props => [shapeId];
}

class DeselectShape extends FlowchartEvent {}