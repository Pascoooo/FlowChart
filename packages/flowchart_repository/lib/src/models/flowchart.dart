import '../entities/flowchart_entity.dart';
import 'flow_node.dart';

class Flowchart {
  final String flowchartId;
  final String name;
  final int schemaVersion;
  final List<FlowNode> nodes;
  final List<FlowchartEdge> edges;

  const Flowchart({
    required this.flowchartId,
    required this.name,
    required this.schemaVersion,
    required this.nodes,
    required this.edges,
  });

  /// **METODO AGGIUNTO**
  /// Crea una copia dell'oggetto Flowchart, aggiornando solo i campi forniti.
  Flowchart copyWith({
    String? flowchartId,
    String? name,
    int? schemaVersion,
    List<FlowNode>? nodes,
    List<FlowchartEdge>? edges,
  }) {
    return Flowchart(
      flowchartId: flowchartId ?? this.flowchartId,
      name: name ?? this.name,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
    );
  }

  FlowchartEntity toEntity() {
    return FlowchartEntity(
      flowchartId: flowchartId,
      name: name,
      schemaVersion: schemaVersion,
      nodes: nodes.map((n) => n.toEntity()).toList(),
      edges: edges.map((e) => e.toEntity()).toList(),
    );
  }

  static Flowchart fromEntity(FlowchartEntity entity) {
    return Flowchart(
      flowchartId: entity.flowchartId,
      name: entity.name,
      schemaVersion: entity.schemaVersion,
      nodes: entity.nodes.map((e) => FlowNode.fromEntity(e)).toList(),
      edges: entity.edges.map((e) => FlowchartEdge.fromEntity(e)).toList(),
    );
  }

  /// Restituisce tutte le variabili dichiarate nei nodi di input (uniche per nome, primo incontro vince).
  List<VariableDeclaration> get allVariables {
    final collected = <VariableDeclaration>[];
    final seen = <String>{};
    for (final n in nodes) {
      if (n is InputNode) {
        for (final d in n.declarations) {
          if (!seen.contains(d.name)) {
            seen.add(d.name);
            collected.add(d);
          }
        }
      }
    }
    return collected;
  }
}