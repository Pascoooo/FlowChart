// pascoooo/flowchart/FlowChart-rework/lib/blocs/flowchart_bloc/flowchart_state.dart
import 'package:equatable/equatable.dart';
import 'dart:convert';

// --- IMPROVEMENT 1: Made FlowchartShape Equatable ---
class FlowchartShape extends Equatable {
  final String id;
  final String type;
  final double x;
  final double y;
  final Map<String, dynamic> properties;

  const FlowchartShape({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.properties = const {},
  });

  FlowchartShape copyWith({
    double? x,
    double? y,
    Map<String, dynamic>? properties,
  }) {
    return FlowchartShape(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      properties: properties ?? this.properties,
    );
  }

  // --- IMPROVEMENT 2: Added JSON serialization ---
  factory FlowchartShape.fromJson(Map<String, dynamic> json) {
    return FlowchartShape(
      id: json['id'],
      type: json['type'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      properties: Map<String, dynamic>.from(json['properties']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'properties': properties,
    };
  }

  @override
  List<Object?> get props => [id, type, x, y, properties];
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
    this.shapes = const [],
    this.selectedShapeId,
  });

  // --- IMPROVEMENT 2: Added JSON serialization helpers ---
  String toJson() {
    final List<Map<String, dynamic>> shapesJson =
    shapes.map((shape) => shape.toJson()).toList();
    return jsonEncode(shapesJson);
  }

  factory FlowchartLoaded.fromJson(String jsonString) {
    if (jsonString.isEmpty) {
      return const FlowchartLoaded(shapes: []);
    }
    try {
      final List<dynamic> shapesJson = jsonDecode(jsonString);
      final List<FlowchartShape> shapes =
      shapesJson.map((json) => FlowchartShape.fromJson(json)).toList();
      return FlowchartLoaded(shapes: shapes);
    } catch (e) {
      // If parsing fails, return an empty state
      return const FlowchartLoaded(shapes: []);
    }
  }

  @override
  List<Object?> get props => [shapes, selectedShapeId];
}