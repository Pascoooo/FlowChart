// lib/blocs/flowchart_bloc/flowchart_event.dart
import 'package:equatable/equatable.dart';
import 'flowchart_state.dart';

abstract class FlowchartEvent extends Equatable {
  const FlowchartEvent();

  @override
  List<Object?> get props => [];
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

class SelectShape extends FlowchartEvent {
  final String shapeId;

  const SelectShape(this.shapeId);

  @override
  List<Object?> get props => [shapeId];
}

class DeselectShape extends FlowchartEvent {}
