import 'flow_node_entity.dart';

/// Rappresenta l'intero documento del flowchart in Firestore.
class FlowchartEntity {
  final String flowchartId;
  final String name;
  final int schemaVersion;
  final List<FlowNodeEntity> nodes;
  final List<EdgeEntity> edges;

  FlowchartEntity({
    required this.flowchartId, required this.name, required this.schemaVersion,
    required this.nodes, required this.edges,
  });

  Map<String, dynamic> toDocument() {
    return {
      'flowchartId': flowchartId, 'name': name, 'schemaVersion': schemaVersion,
      'nodes': nodes.map((n) => n.toDocument()).toList(),
      'edges': edges.map((e) => e.toDocument()).toList(),
    };
  }

  static FlowchartEntity fromDocument(Map<String, dynamic> doc) {
    return FlowchartEntity(
      flowchartId: doc['flowchartId'],
      name: doc['name'],
      schemaVersion: doc['schemaVersion'] ?? 1,
      nodes: (doc['nodes'] as List).map((n) => FlowNodeEntity.fromDocument(n)).toList(),
      edges: (doc['edges'] as List).map((e) => EdgeEntity.fromDocument(e)).toList(),
    );
  }
}