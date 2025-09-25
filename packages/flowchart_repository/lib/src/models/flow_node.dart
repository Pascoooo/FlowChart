import 'package:equatable/equatable.dart';
import '../entities/entities.dart';

/// Versione dello schema dati. Essenziale per gestire future migrazioni.
const int kFlowNodeSchemaVersion = 2;

/// Enum fortemente tipizzato per i tipi di nodi.
enum FlowNodeKind { start, end, process, decision, input, output }

/// Rappresenta una singola dichiarazione di variabile.
class VariableDeclaration extends Equatable {
  final String name;
  final String dataType;
  final dynamic defaultValue;

  const VariableDeclaration({
    required this.name,
    required this.dataType,
    required this.defaultValue,
  });

  @override
  List<Object?> get props => [name, dataType, defaultValue];

  Map<String, dynamic> toJson() => {
    'name': name,
    'dataType': dataType,
    'defaultValue': defaultValue,
  };

  factory VariableDeclaration.fromJson(Map<String, dynamic> json) {
    return VariableDeclaration(
      name: json['name'],
      dataType: json['dataType'],
      defaultValue: json['defaultValue'],
    );
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
    switch (entity.kind) {
      case FlowNodeKind.start:
        return StartNode.fromEntity(entity);
      case FlowNodeKind.end:
        return EndNode.fromEntity(entity);
      case FlowNodeKind.process:
        return ProcessNode.fromEntity(entity);
      case FlowNodeKind.decision:
        return DecisionNode.fromEntity(entity);
      case FlowNodeKind.input:
        return InputNode.fromEntity(entity, allVariables);
      case FlowNodeKind.output:
        return OutputNode.fromEntity(entity);
    }
  }

  @override
  List<Object?> get props => [id, kind, x, y, width, height, text, metadata];
}

class StartNode extends FlowNode {
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

class InputNode extends FlowNode {
  final List<VariableDeclaration> declarations;
  const InputNode(
      {required super.id,
        required super.x,
        required super.y,
        required super.width,
        required super.height,
        required super.text,
        this.declarations = const [],
        super.metadata})
      : super(kind: FlowNodeKind.input);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
    id: id,
    kind: kind,
    x: x,
    y: y,
    width: width,
    height: height,
    text: text,
    data: {'targetVariables': declarations.map((d) => d.name).toList()},
    metadata: metadata,
  );
  static InputNode fromEntity(
      FlowNodeEntity e, List<VariableDeclaration> allVariables) {
    final targetNames =
        (e.data?['targetVariables'] as List?)?.cast<String>() ?? [];
    final declarations = targetNames
        .map((name) => allVariables.firstWhere((v) => v.name == name,
        orElse: () => VariableDeclaration(
            name: name, dataType: 'unknown', defaultValue: null)))
        .toList();

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

  @override
  List<Object?> get props => [...super.props, declarations];

  InputNode copyWith(
      {double? x,
        double? y,
        String? text,
        List<VariableDeclaration>? declarations}) {
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

class OutputNode extends FlowNode {
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
    variables: (e.data?['variables'] as List?)?.cast<String>() ?? const [],
    metadata: e.metadata,
  );
  @override
  List<Object?> get props => [...super.props, template, variables];

  OutputNode copyWith(
      {double? x,
        double? y,
        String? text,
        String? template,
        List<String>? variables}) {
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