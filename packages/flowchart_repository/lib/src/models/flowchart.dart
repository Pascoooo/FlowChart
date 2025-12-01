import 'package:equatable/equatable.dart';
import '../entities/flowchart_entity.dart';
import 'flow_node.dart';
import 'flowchart_type.dart';

/// Rappresenta la firma di un flowchart (parametri e tipo di ritorno).
/// Definisce l'interfaccia del flowchart come una funzione richiamabile.
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

/// Rappresenta un flowchart completo con nodi, collegamenti e metadati.
/// Può essere di tipo 'main' (programma principale) o 'function' (sottoprogramma).
/// Include la signature per flowchart richiamabili e la lista di variabili dichiarate.
class Flowchart extends Equatable {
  final String flowchartId;
  final String name;
  final int schemaVersion;
  final FlowchartType type;
  final FlowchartSignature signature;
  final List<VariableDeclaration> variables;
  final List<FlowNode> nodes;
  final List<FlowchartEdge> edges;

  const Flowchart({
    required this.flowchartId,
    required this.name,
    required this.schemaVersion,
    this.type = FlowchartType.main,
    this.signature = const FlowchartSignature(),
    this.variables = const [],
    required this.nodes,
    required this.edges,
  });

  /// Verifica se il flowchart è di tipo main
  bool get isMain => type == FlowchartType.main;

  /// Verifica se il flowchart è un sottoprogramma
  bool get isFunction => type == FlowchartType.function;

  /// Crea una copia del Flowchart con i campi specificati aggiornati.
  /// Tutti i parametri sono opzionali; i campi non specificati mantengono il valore corrente.
  Flowchart copyWith({
    String? flowchartId,
    String? name,
    int? schemaVersion,
    FlowchartType? type,
    FlowchartSignature? signature,
    List<VariableDeclaration>? variables,
    List<FlowNode>? nodes,
    List<FlowchartEdge>? edges,
  }) {
    return Flowchart(
      flowchartId: flowchartId ?? this.flowchartId,
      name: name ?? this.name,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      type: type ?? this.type,
      signature: signature ?? this.signature,
      variables: variables ?? this.variables,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
    );
  }

  /// Converte il Flowchart in FlowchartEntity per la persistenza.
  /// Serializza tutti i nodi e gli edge nelle loro rappresentazioni entity.
  FlowchartEntity toEntity() {
    return FlowchartEntity(
      flowchartId: flowchartId,
      name: name,
      schemaVersion: schemaVersion,
      type: type,
      signature: signature,
      variables: variables,
      nodes: nodes.map((n) => n.toEntity()).toList(),
      edges: edges.map((e) => e.toEntity()).toList(),
    );
  }

  /// Crea un Flowchart da FlowchartEntity (deserializzazione).
  /// Ricostruisce tutti i nodi dal loro formato entity usando il factory pattern.
  static Flowchart fromEntity(FlowchartEntity entity) {
    final allVariables = entity.variables;
    return Flowchart(
      flowchartId: entity.flowchartId,
      name: entity.name,
      schemaVersion: entity.schemaVersion,
      type: entity.type,
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
      [flowchartId, name, schemaVersion, type, signature, variables, nodes, edges];
}

