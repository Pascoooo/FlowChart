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

  /// Converte il modello [Flowchart] in una [FlowchartEntity].
  FlowchartEntity toEntity() {
    return FlowchartEntity(
      flowchartId: flowchartId,
      name: name,
      shapes: shapes.map((s) => s.toEntity()).toList(),
      connections: connections.map((c) => c.toEntity()).toList(),
    );
  }

  /// Crea un modello [Flowchart] da una [FlowchartEntity].
  static Flowchart fromEntity(FlowchartEntity entity) {
    return Flowchart(
      flowchartId: entity.flowchartId,
      name: entity.name,
      shapes: entity.shapes.map((s) => Shape.fromEntity(s)).toList(),
      connections: entity.connections.map((c) => Connection.fromEntity(c)).toList(),
    );
  }
}