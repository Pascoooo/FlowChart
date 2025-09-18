// pascoooo/flowchart/FlowChart-rework/lib/blocs/flowchart_bloc/flowchart_state.dart
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

  // CORREZIONE: Uso di parametri con nome opzionali per gestire null espliciti
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

  // Metodi helper per semplificare l'uso
  FlowchartLoaded withShapes(List<FlowchartShape> shapes) =>
      copyWith(shapes: shapes);

  FlowchartLoaded withSelection(String? shapeId) =>
      copyWith(selectedShapeId: shapeId);

  FlowchartLoaded clearSelection() =>
      copyWith(clearSelection: true);

  // AGGIUNTO: Metodo specifico per deselezionare
  FlowchartLoaded deselect() {
    return FlowchartLoaded(
      shapes: shapes,
      selectedShapeId: null,
    );
  }

  String toJson() {
    final List<Map<String, dynamic>> shapesJson =
    shapes.map((shape) => shape.toJson()).toList();
    return jsonEncode(shapesJson);
  }

  factory FlowchartLoaded.fromJson(String jsonString) {
    List<FlowchartShape> parsed = const [];
    if (jsonString.isEmpty) {
      final start = _defaultStartShape();
      return FlowchartLoaded(shapes: [start], selectedShapeId: start.id);
    }
    try {
      final List<dynamic> shapesJson = jsonDecode(jsonString);
      parsed = shapesJson.map((json) => FlowchartShape.fromJson(json)).toList();
    } catch (e) {
      final start = _defaultStartShape();
      return FlowchartLoaded(shapes: [start], selectedShapeId: start.id);
    }

    if (parsed.isEmpty) {
      final start = _defaultStartShape();
      return FlowchartLoaded(shapes: [start], selectedShapeId: start.id);
    }
    return FlowchartLoaded(shapes: parsed);
  }

  static FlowchartShape _defaultStartShape() {
    final id = 'start_${DateTime.now().microsecondsSinceEpoch}';
    return FlowchartShape(
      id: id,
      type: 'circle',
      x: 120,
      y: 120,
      properties: const {
        'width': 90.0,
        'height': 90.0,
        'text': 'Start',
      },
    );
  }

  @override
  List<Object?> get props => [shapes, selectedShapeId];
}