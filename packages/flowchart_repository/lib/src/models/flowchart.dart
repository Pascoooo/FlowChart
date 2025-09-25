import 'package:equatable/equatable.dart';
import '../entities/flowchart_entity.dart';
import 'flow_node.dart';

/// Rappresenta i parametri e il tipo di ritorno di un flowchart,
/// definendo la sua firma come se fosse una funzione.
class FlowchartSignature extends Equatable {
  final List<FunctionParam> parameters;
  final String returnType;

  const FlowchartSignature({
    this.parameters = const [],
    this.returnType = 'void',
  });

  @override
  List<Object?> get props => [parameters, returnType];
}

class Flowchart extends Equatable {
  final String flowchartId;
  final String name;
  final int schemaVersion;
  final FlowchartSignature signature;
  final List<VariableDeclaration> variables;
  final List<FlowNode> nodes;
  final List<FlowchartEdge> edges;

  const Flowchart({
    required this.flowchartId,
    required this.name,
    required this.schemaVersion,
    this.signature = const FlowchartSignature(),
    this.variables = const [],
    required this.nodes,
    required this.edges,
  });

  Flowchart copyWith({
    String? flowchartId,
    String? name,
    int? schemaVersion,
    FlowchartSignature? signature,
    List<VariableDeclaration>? variables,
    List<FlowNode>? nodes,
    List<FlowchartEdge>? edges,
  }) {
    return Flowchart(
      flowchartId: flowchartId ?? this.flowchartId,
      name: name ?? this.name,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      signature: signature ?? this.signature,
      variables: variables ?? this.variables,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
    );
  }

  FlowchartEntity toEntity() {
    return FlowchartEntity(
      flowchartId: flowchartId,
      name: name,
      schemaVersion: schemaVersion,
      signature: signature,
      variables: variables,
      nodes: nodes.map((n) => n.toEntity()).toList(),
      edges: edges.map((e) => e.toEntity()).toList(),
    );
  }

  static Flowchart fromEntity(FlowchartEntity entity) {
    final allVariables = entity.variables;
    return Flowchart(
      flowchartId: entity.flowchartId,
      name: entity.name,
      schemaVersion: entity.schemaVersion,
      signature: entity.signature,
      variables: allVariables,
      nodes: entity.nodes
          .map((e) => FlowNode.fromEntity(e, allVariables))
          .toList(),
      edges: entity.edges.map((e) => FlowchartEdge.fromEntity(e)).toList(),
    );
  }

  @override
  List<Object?> get props =>
      [flowchartId, name, schemaVersion, signature, variables, nodes, edges];
}