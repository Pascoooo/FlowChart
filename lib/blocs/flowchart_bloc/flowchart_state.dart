import 'dart:convert';
import 'dart:developer';
import 'package:equatable/equatable.dart';

//##############################################################################
// # MODELLO FLOWCHART SHAPE "INTELLIGENTE"
//##############################################################################

class FlowchartShape extends Equatable {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String text;

  /// Lista degli ID delle connessioni in entrata.
  /// Rende la forma "consapevole" del suo stato nel grafo.
  final List<String> incomingConnectionIds;

  /// Lista degli ID delle connessioni in uscita.
  final List<String> outgoingConnectionIds;

  const FlowchartShape({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
    this.incomingConnectionIds = const [],
    this.outgoingConnectionIds = const [],
  });

  /// Getter per la logica di business: numero massimo di connessioni in uscita.
  int get maxOutgoingConnections {
    switch (type) {
      case 'decision':
        return 2;
      case 'end':
        return 0;
      default:
        return 1;
    }
  }

  /// Getter per la logica di business: numero massimo di connessioni in entrata.
  int get maxIncomingConnections {
    switch (type) {
      case 'start':
        return 0;
      default:
        return 1;
    }
  }

  /// Getter per la UI: determina se il pulsante '+' debba essere mostrato.
  bool get canAddOutgoingConnection =>
      outgoingConnectionIds.length < maxOutgoingConnections;

  /// Metodo copyWith per aggiornamenti immutabili dello stato.
  FlowchartShape copyWith({
    String? id,
    String? type,
    double? x,
    double? y,
    double? width,
    double? height,
    String? text,
    List<String>? incomingConnectionIds,
    List<String>? outgoingConnectionIds,
  }) {
    return FlowchartShape(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      incomingConnectionIds:
      incomingConnectionIds ?? this.incomingConnectionIds,
      outgoingConnectionIds:
      outgoingConnectionIds ?? this.outgoingConnectionIds,
    );
  }

  /// Deserializza una forma da JSON. Nota: non popola le liste di connessioni,
  /// se ne occuperà FlowchartLoaded.
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

  /// Serializza una forma in JSON. Nota: non include le liste di connessioni
  /// per evitare ridondanza di dati.
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
  List<Object?> get props => [
    id,
    type,
    x,
    y,
    width,
    height,
    text,
    incomingConnectionIds,
    outgoingConnectionIds
  ];
}

//##############################################################################
// # MODELLO FLOWCHART CONNECTION
//##############################################################################

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

//##############################################################################
// # STATI DEL BLOC
//##############################################################################

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

  /// Costruttore Factory che deserializza il JSON e costruisce lo stato "ricco".
  /// Questa è la logica centrale che rende i modelli "intelligenti".
  factory FlowchartLoaded.fromJson(String jsonString) {
    // Se il JSON è vuoto, ritorna uno stato iniziale pulito.
    if (jsonString.isEmpty) {
      return const FlowchartLoaded();
    }
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

      // 1. Carica le liste "piatte" di forme e connessioni
      final baseShapes = (jsonMap['shapes'] as List<dynamic>?)
          ?.map((json) => FlowchartShape.fromJson(json))
          .toList() ??
          [];
      final connections = (jsonMap['connections'] as List<dynamic>?)
          ?.map((json) => FlowchartConnection.fromJson(json))
          .toList() ??
          [];

      if (baseShapes.isEmpty) return const FlowchartLoaded();

      // 2. Crea una mappa per un accesso efficiente O(1) alle forme
      final shapeMap = {for (var shape in baseShapes) shape.id: shape};

      // 3. Itera sulle connessioni UNA SOLA VOLTA per popolare le liste di ogni forma
      for (final connection in connections) {
        // Aggiorna la forma di partenza (from)
        if (shapeMap.containsKey(connection.fromShapeId)) {
          final fromShape = shapeMap[connection.fromShapeId]!;
          final updatedOutgoing = List<String>.from(fromShape.outgoingConnectionIds)
            ..add(connection.id);
          shapeMap[connection.fromShapeId] =
              fromShape.copyWith(outgoingConnectionIds: updatedOutgoing);
        }
        // Aggiorna la forma di destinazione (to)
        if (shapeMap.containsKey(connection.toShapeId)) {
          final toShape = shapeMap[connection.toShapeId]!;
          final updatedIncoming = List<String>.from(toShape.incomingConnectionIds)
            ..add(connection.id);
          shapeMap[connection.toShapeId] =
              toShape.copyWith(incomingConnectionIds: updatedIncoming);
        }
      }

      // 4. Costruisce lo stato finale con la lista di forme "arricchite"
      return FlowchartLoaded(
        shapes: shapeMap.values.toList(),
        connections: connections,
      );
    } catch (e, stackTrace) {
      log("Errore critico nel parsing del JSON del flowchart: $e", stackTrace: stackTrace);
      // In caso di errore, ritorna uno stato vuoto per evitare crash.
      return const FlowchartLoaded();
    }
  }

  String toJson() {
    final Map<String, dynamic> jsonMap = {
      'shapes': shapes.map((shape) => shape.toJson()).toList(),
      'connections': connections.map((conn) => conn.toJson()).toList(),
    };
    return jsonEncode(jsonMap);
  }

  FlowchartLoaded copyWith({
    List<FlowchartShape>? shapes,
    List<FlowchartConnection>? connections,
    String? selectedShapeId,
    bool clearSelection = false,
  }) {
    return FlowchartLoaded(
      shapes: shapes ?? this.shapes,
      connections: connections ?? this.connections,
      selectedShapeId:
      clearSelection ? null : (selectedShapeId ?? this.selectedShapeId),
    );
  }

  FlowchartLoaded deselect() {
    return copyWith(clearSelection: true);
  }

  @override
  List<Object?> get props => [shapes, connections, selectedShapeId];
}