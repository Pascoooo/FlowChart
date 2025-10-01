import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/src/entities/entities.dart';

/// Versione dello schema dati. Essenziale per gestire future migrazioni.
const int kFlowNodeSchemaVersion = 2;

/// Enum fortemente tipizzato per i tipi di nodi.
// MODIFICATO: Aggiunto il nuovo tipo di nodo 'assignment'.
enum FlowNodeKind { start, end, process, decision, input, output, assignment }
// NUOVO: Enum per le categorie di variabili
enum VariableScope {
  input,
  output,
  local,
}

/// Rappresenta una singola dichiarazione di variabile.
// MODIFICATO: Rimossa la proprietà 'defaultValue'.
class VariableDeclaration extends Equatable {
  final String name;
  final String dataType;
  final VariableScope scope;

  const VariableDeclaration({
    required this.name,
    required this.dataType,
    this.scope = VariableScope.local,
  });

  @override
  List<Object?> get props => [name, dataType, scope];

  VariableDeclaration copyWith({
    String? name,
    String? dataType,
    VariableScope? scope,
  }) {
    return VariableDeclaration(
      name: name ?? this.name,
      dataType: dataType ?? this.dataType,
      scope: scope ?? this.scope,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'dataType': dataType,
    'scope': scope.name,
  };

  factory VariableDeclaration.fromMap(Map<String, dynamic> map) {
    return VariableDeclaration(
      name: map['name'],
      dataType: map['dataType'],
      scope: VariableScope.values.firstWhere(
            (e) => e.name == map['scope'],
        orElse: () => VariableScope.local,
      ),
    );
  }
}

/// Rappresenta una singola operazione di assegnazione.
class Assignment extends Equatable {
  final String target;
  final String expression;

  const Assignment({required this.target, required this.expression});

  @override
  List<Object?> get props => [target, expression];

  Map<String, dynamic> toMap() => {'target': target, 'expression': expression};

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(target: map['target'], expression: map['expression']);
  }
}

/// Classe base astratta per tutti i nodi del diagramma di flusso.
abstract class FlowNode extends Equatable {
  final String id;
  final FlowNodeKind kind;
  final double x, y, width, height;
  final String text;
  final Map<String, dynamic>? metadata;

  const FlowNode({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
    this.metadata,
  });

  FlowNodeEntity toEntity();

  static FlowNode fromEntity(
      FlowNodeEntity entity, List<VariableDeclaration> allVariables) {
    return switch (entity.kind) {
      FlowNodeKind.start => StartNode.fromEntity(entity),
      FlowNodeKind.end => EndNode.fromEntity(entity),
      FlowNodeKind.process => ProcessNode.fromEntity(entity),
      FlowNodeKind.decision => DecisionNode.fromEntity(entity),
      FlowNodeKind.input => InputNode.fromEntity(entity, allVariables),
      FlowNodeKind.output => OutputNode.fromEntity(entity),
      FlowNodeKind.assignment => AssignmentNode.fromEntity(entity),
    };
  }

  @override
  List<Object?> get props => [id, kind, x, y, width, height, text, metadata];
}


class StartNode extends FlowNode {
  // ... (Nessuna modifica qui)
  const StartNode(
      {required super.id,
        required super.x,
        required super.y,
        required super.width,
        required super.height,
        required super.text,
        super.metadata})
      : super(kind: FlowNodeKind.start);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
      id: id,
      kind: kind,
      x: x,
      y: y,
      width: width,
      height: height,
      text: text,
      metadata: metadata);
  static StartNode fromEntity(FlowNodeEntity e) => StartNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      metadata: e.metadata);

  StartNode copyWith({double? x, double? y}) {
    return StartNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text,
      metadata: metadata,
    );
  }
}

class EndNode extends FlowNode {
  // ... (Nessuna modifica qui)
  const EndNode(
      {required super.id,
        required super.x,
        required super.y,
        required super.width,
        required super.height,
        required super.text,
        super.metadata})
      : super(kind: FlowNodeKind.end);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
      id: id,
      kind: kind,
      x: x,
      y: y,
      width: width,
      height: height,
      text: text,
      metadata: metadata);
  static EndNode fromEntity(FlowNodeEntity e) => EndNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      metadata: e.metadata);

  EndNode copyWith({double? x, double? y}) {
    return EndNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text,
      metadata: metadata,
    );
  }
}

class FunctionParam extends Equatable {
  // ... (Nessuna modifica qui)
  final String name;
  final String type;
  const FunctionParam({required this.name, required this.type});
  Map<String, dynamic> toJson() => {'name': name, 'type': type};
  factory FunctionParam.fromJson(Map<String, dynamic> json) =>
      FunctionParam(name: json['name'], type: json['type']);
  @override
  List<Object?> get props => [name, type];
}

class ProcessNode extends FlowNode {
  // ... (Nessuna modifica qui)
  final String flowchartToCall;
  final List<String> arguments;
  final String? resultTarget;

  const ProcessNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.flowchartToCall = '',
    this.arguments = const [],
    this.resultTarget,
    super.metadata,
  }) : super(kind: FlowNodeKind.process);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
    id: id,
    kind: kind,
    x: x,
    y: y,
    width: width,
    height: height,
    text: text,
    data: {
      'flowchartToCall': flowchartToCall,
      'arguments': arguments,
      if (resultTarget != null) 'resultTarget': resultTarget,
    },
    metadata: metadata,
  );

  static ProcessNode fromEntity(FlowNodeEntity e) {
    return ProcessNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      flowchartToCall: e.data?['flowchartToCall'] ?? '',
      arguments: (e.data?['arguments'] as List?)?.cast<String>() ?? [],
      resultTarget: e.data?['resultTarget'],
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, flowchartToCall, arguments, resultTarget];

  ProcessNode copyWith({
    double? x,
    double? y,
    String? text,
    String? flowchartToCall,
    List<String>? arguments,
    String? resultTarget,
  }) {
    return ProcessNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      flowchartToCall: flowchartToCall ?? this.flowchartToCall,
      arguments: arguments ?? this.arguments,
      resultTarget: resultTarget ?? this.resultTarget,
      metadata: metadata,
    );
  }
}

class DecisionNode extends FlowNode {
  // ... (Nessuna modifica qui)
  final String condition;
  const DecisionNode(
      {required super.id,
        required super.x,
        required super.y,
        required super.width,
        required super.height,
        required super.text,
        this.condition = '',
        super.metadata})
      : super(kind: FlowNodeKind.decision);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
      id: id,
      kind: kind,
      x: x,
      y: y,
      width: width,
      height: height,
      text: text,
      data: {'condition': condition},
      metadata: metadata);
  static DecisionNode fromEntity(FlowNodeEntity e) => DecisionNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      condition: e.data?['condition'] ?? '',
      metadata: e.metadata);
  @override
  List<Object?> get props => [...super.props, condition];

  DecisionNode copyWith(
      {double? x, double? y, String? text, String? condition}) {
    return DecisionNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      condition: condition ?? this.condition,
      metadata: metadata,
    );
  }
}

// MODIFICATO: InputNode è stato semplificato.
class InputNode extends FlowNode {
  final List<VariableDeclaration> declarations;
  // RIMOSSO: La lista di 'assignments' è stata tolta da questo nodo.
  // final List<Assignment> assignments;

  const InputNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.declarations = const [],
    // RIMOSSO: 'assignments' rimosso dal costruttore.
    // this.assignments = const [],
    super.metadata,
  }) : super(kind: FlowNodeKind.input);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
    id: id,
    kind: kind,
    x: x,
    y: y,
    width: width,
    height: height,
    text: text,
    data: {
      'targetVariables': declarations.map((d) => d.name).toList(),
      // RIMOSSO: Serializzazione di 'assignments' tolta.
    },
    metadata: metadata,
  );

  static InputNode fromEntity(
      FlowNodeEntity e, List<VariableDeclaration> allVariables) {
    final targetNames = (e.data?['targetVariables'] as List?)?.cast<String>() ?? [];
    final declarations = targetNames
        .map((name) => allVariables.firstWhere((v) => v.name == name,
        orElse: () =>
            VariableDeclaration(name: name, dataType: 'unknown')))
        .toList();

    // RIMOSSO: Deserializzazione di 'assignments' tolta.

    return InputNode(
        id: e.id,
        x: e.x,
        y: e.y,
        width: e.width,
        height: e.height,
        text: e.text,
        declarations: declarations,
        metadata: e.metadata);
  }

  // MODIFICATO: 'assignments' rimosso da props e copyWith.
  @override
  List<Object?> get props => [...super.props, declarations];

  InputNode copyWith({
    double? x,
    double? y,
    String? text,
    List<VariableDeclaration>? declarations,
  }) {
    return InputNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      declarations: declarations ?? this.declarations,
      metadata: metadata,
    );
  }
}

// NUOVO: La classe per il nodo di Assegnazione.
class AssignmentNode extends FlowNode {
  final List<Assignment> assignments;

  const AssignmentNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.assignments = const [],
    super.metadata,
  }) : super(kind: FlowNodeKind.assignment);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
    id: id,
    kind: kind,
    x: x,
    y: y,
    width: width,
    height: height,
    text: text,
    data: {'assignments': assignments.map((a) => a.toMap()).toList()},
    metadata: metadata,
  );

  static AssignmentNode fromEntity(FlowNodeEntity e) {
    final assignmentsData = e.data?['assignments'] as List? ?? [];
    final assignments = assignmentsData
        .map((a) => Assignment.fromMap(a as Map<String, dynamic>))
        .toList();
    return AssignmentNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      assignments: assignments,
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, assignments];

  AssignmentNode copyWith({
    double? x,
    double? y,
    String? text,
    List<Assignment>? assignments,
  }) {
    return AssignmentNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      assignments: assignments ?? this.assignments,
      metadata: metadata,
    );
  }
}

class OutputNode extends FlowNode {
  // ... (Nessuna modifica qui)
  final String template;
  final List<String> variables;
  const OutputNode(
      {required super.id,
        required super.x,
        required super.y,
        required super.width,
        required super.height,
        required super.text,
        this.template = '',
        this.variables = const [],
        super.metadata})
      : super(kind: FlowNodeKind.output);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
    id: id,
    kind: kind,
    x: x,
    y: y,
    width: width,
    height: height,
    text: text,
    data: {
      'template': template,
      'variables': variables,
    },
    metadata: metadata,
  );
  static OutputNode fromEntity(FlowNodeEntity e) => OutputNode(
    id: e.id,
    x: e.x,
    y: e.y,
    width: e.width,
    height: e.height,
    text: e.text,
    template: e.data?['template'] ?? '',
    variables:
    (e.data?['variables'] as List?)?.cast<String>() ?? const [],
    metadata: e.metadata,
  );
  @override
  List<Object?> get props => [...super.props, template, variables];

  OutputNode copyWith({
    double? x,
    double? y,
    String? text,
    String? template,
    List<String>? variables,
  }) {
    return OutputNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      template: template ?? this.template,
      variables: variables ?? this.variables,
      metadata: metadata,
    );
  }
}

class FlowchartEdge extends Equatable {
  // ... (Nessuna modifica qui)
  final String from;
  final String to;
  final String? port;

  const FlowchartEdge({required this.from, required this.to, this.port});

  EdgeEntity toEntity() => EdgeEntity(from: from, to: to, port: port);
  static FlowchartEdge fromEntity(EdgeEntity entity) =>
      FlowchartEdge(from: entity.from, to: entity.to, port: entity.port);

  @override
  List<Object?> get props => [from, to, port];
}