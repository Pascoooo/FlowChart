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

// NUOVA CLASSE PER RAPPRESENTARE UNA CONNESSIONE NELLO STATO DELLA UI
class FlowchartConnection extends Equatable {
  final String id;
  final String fromShapeId;
  final String toShapeId;

  const FlowchartConnection({
    required this.id,
    required this.fromShapeId,
    required this.toShapeId,
  });

  factory FlowchartConnection.fromJson(Map<String, dynamic> json) {
    return FlowchartConnection(
      id: json['id'],
      fromShapeId: json['fromShapeId'],
      toShapeId: json['toShapeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromShapeId': fromShapeId,
      'toShapeId': toShapeId,
    };
  }

  @override
  List<Object?> get props => [id, fromShapeId, toShapeId];
}

abstract class FlowchartState extends Equatable {
  const FlowchartState();

  @override
  List<Object?> get props => [];
}

class FlowchartInitial extends FlowchartState {}

class FlowchartLoaded extends FlowchartState {
  final List<FlowchartShape> shapes;
  final List<FlowchartConnection> connections; // STATO ARRICCHITO
  final String? selectedShapeId;

  const FlowchartLoaded({
    this.shapes = const [],
    this.connections = const [], // VALORE DI DEFAULT
    this.selectedShapeId,
  });

  FlowchartLoaded copyWith({
    List<FlowchartShape>? shapes,
    List<FlowchartConnection>? connections,
    String? selectedShapeId,
    bool clearSelection = false,
  }) {
    return FlowchartLoaded(
      shapes: shapes ?? this.shapes,
      connections: connections ?? this.connections,
      selectedShapeId: clearSelection ? null : (selectedShapeId ?? this.selectedShapeId),
    );
  }

  FlowchartLoaded deselect() {
    return copyWith(clearSelection: true);
  }

  // AGGIORNATO PER RISPECCHIARE LA STRUTTURA DEL BACKEND
  String toJson() {
    final Map<String, dynamic> jsonMap = {
      'shapes': shapes.map((shape) => shape.toJson()).toList(),
      'connections': connections.map((conn) => conn.toJson()).toList(),
    };
    return jsonEncode(jsonMap);
  }

  // AGGIORNATO PER LEGGERE LA NUOVA STRUTTURA
  factory FlowchartLoaded.fromJson(String jsonString) {
    if (jsonString.isEmpty) {
      return FlowchartLoaded(shapes: [_defaultStartShape()]);
    }
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final shapes = (jsonMap['shapes'] as List<dynamic>?)
          ?.map((json) => FlowchartShape.fromJson(json))
          .toList() ?? [];
      final connections = (jsonMap['connections'] as List<dynamic>?)
          ?.map((json) => FlowchartConnection.fromJson(json))
          .toList() ?? [];

      if (shapes.isEmpty) {
        return FlowchartLoaded(shapes: [_defaultStartShape()]);
      }
      return FlowchartLoaded(shapes: shapes, connections: connections);

    } catch (e) {
      return FlowchartLoaded(shapes: [_defaultStartShape()]);
    }
  }

  static FlowchartShape _defaultStartShape() {
    final id = 'start_${DateTime.now().microsecondsSinceEpoch}';
    return FlowchartShape(
      id: id, type: 'circle', x: 120, y: 120,
      properties: const {'width': 90.0, 'height': 90.0, 'text': 'Start'},
    );
  }

  @override
  List<Object?> get props => [shapes, connections, selectedShapeId];
}