// models/flowchart.dart (COMPLETO E MODIFICATO)

import '../../src/entities/flowchart_entity.dart';
import 'connection.dart';
import 'shape.dart';

class Flowchart {
  final String flowchartId;
  final String name;
  final List<Shape> shapes;
  final List<Connection> connections;

  const Flowchart({
    required this.flowchartId,
    required this.name,
    required this.shapes,
    required this.connections,
  });

  FlowchartEntity toEntity() {
    return FlowchartEntity(
      flowchartId: flowchartId,
      name: name,
      shapes: shapes.map((s) => s.toEntity()).toList(),
      connections: connections.map((c) => c.toEntity()).toList(),
    );
  }

  static Flowchart fromEntity(FlowchartEntity entity) {
    // Prima creiamo le forme e le connessioni base
    final baseShapes = entity.shapes.map((s) => Shape.fromEntity(s)).toList();
    final connections = entity.connections.map((c) => Connection.fromEntity(c)).toList();

    // --- LOGICA DI POPOLAMENTO ---
    // Ora arricchiamo ogni forma con le sue connessioni
    final shapeMap = {for (var shape in baseShapes) shape.id: shape};

    for (final connection in connections) {
      // Aggiorna la forma di partenza
      if (shapeMap.containsKey(connection.fromShapeId)) {
        final fromShape = shapeMap[connection.fromShapeId]!;
        final updatedOutgoing = List<String>.from(fromShape.outgoingConnectionIds)..add(connection.id);
        shapeMap[connection.fromShapeId] = fromShape.copyWith(outgoingConnectionIds: updatedOutgoing);
      }
      // Aggiorna la forma di destinazione
      if (shapeMap.containsKey(connection.toShapeId)) {
        final toShape = shapeMap[connection.toShapeId]!;
        final updatedIncoming = List<String>.from(toShape.incomingConnectionIds)..add(connection.id);
        shapeMap[connection.toShapeId] = toShape.copyWith(incomingConnectionIds: updatedIncoming);
      }
    }

    return Flowchart(
      flowchartId: entity.flowchartId,
      name: entity.name,
      shapes: shapeMap.values.toList(),
      connections: connections,
    );
  }
}