import 'package:flowchart_repository/src/models/flow_node.dart';
import '../../flowchart_repository.dart';
import 'flow_node_entity.dart';

class FlowchartEntity {
  final String flowchartId;
  final String name;
  final int schemaVersion;
  final FlowchartSignature signature;
  final List<VariableDeclaration> variables;
  final List<FlowNodeEntity> nodes;
  final List<EdgeEntity> edges;

  FlowchartEntity({
    required this.flowchartId,
    required this.name,
    required this.schemaVersion,
    required this.signature,
    required this.variables,
    required this.nodes,
    required this.edges,
  });

  Map<String, dynamic> toDocument() {
    return {
      'flowchartId': flowchartId,
      'name': name,
      'schemaVersion': schemaVersion,
      'signature': {
        'parameters': signature.parameters.map((p) => p.toJson()).toList(),
        'returnType': signature.returnType,
      },
      'variables': variables.map((v) => v.toJson()).toList(),
      'nodes': nodes.map((n) => n.toDocument()).toList(),
      'edges': edges.map((e) => e.toDocument()).toList(),
    };
  }

  static FlowchartEntity fromDocument(Map<String, dynamic> doc) {
    final signatureDoc = doc['signature'] as Map<String, dynamic>? ?? {};
    final paramsList = signatureDoc['parameters'] as List<dynamic>? ?? [];
    final variablesList = doc['variables'] as List<dynamic>? ?? [];

    return FlowchartEntity(
      flowchartId: doc['flowchartId'],
      name: doc['name'],
      schemaVersion: doc['schemaVersion'] ?? 1,
      signature: FlowchartSignature(
        parameters: paramsList.map((p) => FunctionParam.fromJson(p)).toList(),
        returnType: signatureDoc['returnType'] ?? 'void',
      ),
      variables:
      variablesList.map((v) => VariableDeclaration.fromJson(v)).toList(),
      nodes: (doc['nodes'] as List)
          .map((n) => FlowNodeEntity.fromDocument(n))
          .toList(),
      edges: (doc['edges'] as List)
          .map((e) => EdgeEntity.fromDocument(e))
          .toList(),
    );
  }
}