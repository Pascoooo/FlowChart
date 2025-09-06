// flowchart_state.dart
import 'package:equatable/equatable.dart';

class FlowchartShape {
  final String id;
  final String type; // es: 'rect', 'diamond', 'ellipse'
  final double x;
  final double y;
  final Map<String, dynamic> properties;

  FlowchartShape({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.properties = const {},
  });
}

abstract class FlowchartState extends Equatable {
  const FlowchartState();

  @override
  List<Object?> get props => [];
}

class FlowchartInitial extends FlowchartState {}

class FlowchartLoaded extends FlowchartState {
  final List<FlowchartShape> shapes;
  final String? selectedShapeId;

  const FlowchartLoaded({
    required this.shapes,
    this.selectedShapeId,
  });

  @override
  List<Object?> get props => [shapes, selectedShapeId];
}
