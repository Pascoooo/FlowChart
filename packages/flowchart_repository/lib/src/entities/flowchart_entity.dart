import 'connection_entity.dart';
import 'shape_entity.dart';

class FlowchartEntity {
  final String flowchartId;
  final String name;
  final List<ShapeEntity> shapes;
  final List<ConnectionEntity> connections;

  FlowchartEntity({
    required this.flowchartId,
    required this.name,
    required this.shapes,
    required this.connections,
  });

  /// Converte l'entità in un documento Map.
  Map<String, dynamic> toDocument() {
    return {
      'flowchartId': flowchartId,
      'name': name,
      'shapes': shapes.map((s) => s.toDocument()).toList(),
      'connections': connections.map((c) => c.toDocument()).toList(),
    };
  }

  /// Crea un'entità da un documento Map.
  static FlowchartEntity fromDocument(Map<String, dynamic> doc) {
    return FlowchartEntity(
      flowchartId: doc['flowchartId'] as String,
      name: doc['name'] as String,
      shapes: (doc['shapes'] as List<dynamic>)
          .map((s) => ShapeEntity.fromDocument(s as Map<String, dynamic>))
          .toList(),
      connections: (doc['connections'] as List<dynamic>)
          .map((c) => ConnectionEntity.fromDocument(c as Map<String, dynamic>))
          .toList(),
    );
  }
}