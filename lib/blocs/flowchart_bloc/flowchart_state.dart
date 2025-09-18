import 'package:equatable/equatable.dart';
import 'dart:convert';

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

  FlowchartLoaded copyWith({
    List<FlowchartShape>? shapes,
    String? selectedShapeId,
    bool clearSelection = false,
  }) {
    return FlowchartLoaded(
      shapes: shapes ?? this.shapes,
      selectedShapeId: clearSelection ? null : (selectedShapeId ?? this.selectedShapeId),
    );
  }

  String toJson() {
    final List<Map<String, dynamic>> shapesJson =
    shapes.map((shape) => shape.toJson()).toList();
    return jsonEncode(shapesJson);
  }

  /// Se il contenuto è vuoto o corrotto, crea di default una forma "Start".
  factory FlowchartLoaded.fromJson(String jsonString) {
    if (jsonString.isEmpty) {
      final start = _defaultStartShape();
      return FlowchartLoaded(shapes: [start], selectedShapeId: start.id);
    }
    try {
      final List<dynamic> shapesJson = jsonDecode(jsonString);
      final parsed = shapesJson.map((json) => FlowchartShape.fromJson(json)).toList();
      if (parsed.isEmpty) {
        final start = _defaultStartShape();
        return FlowchartLoaded(shapes: [start], selectedShapeId: start.id);
      }
      return FlowchartLoaded(shapes: parsed);
    } catch (e) {
      final start = _defaultStartShape();
      return FlowchartLoaded(shapes: [start], selectedShapeId: start.id);
    }
  }

  static FlowchartShape _defaultStartShape() {
    final id = 'start_${DateTime.now().microsecondsSinceEpoch}';
    return FlowchartShape(
      id: id,
      type: 'circle',
      x: 120,
      y: 120,
      properties: const {'width': 90.0, 'height': 90.0, 'text': 'Start'},
    );
  }

  @override
  List<Object?> get props => [shapes];
}