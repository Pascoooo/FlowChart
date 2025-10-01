import '../../flowchart_repository.dart';

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
      'variables': variables.map((v) => v.toMap()).toList(),
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
        parameters: paramsList
            .map((p) => FunctionParam.fromJson(p as Map<String, dynamic>))
            .toList(),
        returnType: signatureDoc['returnType'] ?? 'void',
      ),
      // FIX: Chiamato VariableDeclaration.fromMap() invece di fromJson.
      // Aggiunto un cast (as Map<String, dynamic>) per sicurezza sui tipi.
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