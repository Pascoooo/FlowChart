import 'package:flowchart_repository/src/models/flowchart_type.dart';
import 'package:flowchart_repository/src/models/flow_node.dart';

import '../../flowchart_repository.dart';

class FlowchartEntity {
  final String flowchartId;
  final String name;
  final int schemaVersion;
  final FlowchartType type;
  final FlowchartSignature signature;
  final List<VariableDeclaration> variables;
  final List<FlowNodeEntity> nodes;
  final List<EdgeEntity> edges;

  FlowchartEntity({
    required this.flowchartId,
    required this.name,
    required this.schemaVersion,
    this.type = FlowchartType.main,
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
      'type': type.name,
      'signature': {
        'parameters': signature.parameters.map((p) => p.toJson()).toList(),
        'returnType': signature.returnType,
      },
      'variables': variables.map((v) => v.toMap()).toList(),
      'nodes': nodes.map((n) => n.toDocument()).toList(),
      'edges': edges.map((e) => e.toDocument()).toList(),
    };
  }

  static FlowchartEntity fromDocument(Map<String, dynamic> doc) {
    final signatureDoc = doc['signature'] as Map<String, dynamic>? ?? {};
    final paramsList = signatureDoc['parameters'] as List<dynamic>? ?? [];
    final variablesList = doc['variables'] as List<dynamic>? ?? [];

    // Parsing del tipo con fallback a 'main' per retrocompatibilità
    final typeString = doc['type'] as String?;
    final type = typeString != null
        ? FlowchartType.values.firstWhere(
            (e) => e.name == typeString,
            orElse: () => FlowchartType.main,
          )
        : FlowchartType.main;

    return FlowchartEntity(
      flowchartId: doc['flowchartId'],
      name: doc['name'],
      schemaVersion: doc['schemaVersion'] ?? 1,
      type: type,
      signature: FlowchartSignature(
        parameters: paramsList
            .map((p) => FunctionParam.fromJson(p as Map<String, dynamic>))
            .toList(),
        returnType: signatureDoc['returnType'] ?? 'void',
      ),
      variables: variablesList
          .map((v) => VariableDeclaration.fromMap(v as Map<String, dynamic>))
          .toList(),
      nodes: (doc['nodes'] as List)
          .map((n) => FlowNodeEntity.fromDocument(n))
          .toList(),
      edges: (doc['edges'] as List)
          .map((e) => EdgeEntity.fromDocument(e))
          .toList(),
    );
  }
}