import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'dart:convert';

class FlowchartShape extends Equatable {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String text;

  const FlowchartShape({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
  });

  FlowchartShape copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? text,
  }) {
    return FlowchartShape(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
    );
  }

  factory FlowchartShape.fromJson(Map<String, dynamic> json) {
    return FlowchartShape(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      text: json['text'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'text': text,
    };
  }

  @override
  List<Object?> get props => [id, type, x, y, width, height, text];
}

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
      id: json['id'] as String,
      fromShapeId: json['fromShapeId'] as String,
      toShapeId: json['toShapeId'] as String,
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
  final List<FlowchartConnection> connections;
  final String? selectedShapeId;

  const FlowchartLoaded({
    this.shapes = const [],
    this.connections = const [],
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

  String toJson() {
    final Map<String, dynamic> jsonMap = {
      'shapes': shapes.map((shape) => shape.toJson()).toList(),
      'connections': connections.map((conn) => conn.toJson()).toList(),
    };
    return jsonEncode(jsonMap);
  }

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
      id: id,
      type: 'circle',
      x: 120,
      y: 120,
      width: 90.0,
      height: 90.0,
      text: 'Start',
    );
  }

  @override
  List<Object?> get props => [shapes, connections, selectedShapeId];
}
