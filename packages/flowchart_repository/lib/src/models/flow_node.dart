import 'package:equatable/equatable.dart';
import '../entities/entities.dart';

/// Versione dello schema dati. Essenziale per gestire future migrazioni.
const int kFlowNodeSchemaVersion = 1;

/// Enum fortemente tipizzato per i tipi di nodi. Elimina errori e stringhe "magiche".
enum FlowNodeKind { start, end, process, decision, input, output }

/// Rappresenta una singola dichiarazione di variabile (nome, tipo, valore).
/// L'utente la compilerà tramite una UI a form.
class VariableDeclaration extends Equatable {
  final String name;
  final String dataType; // Es. "int", "float", "string"
  final dynamic initialValue; // Il valore iniziale fornito dall'utente

  const VariableDeclaration({
    required this.name,
    required this.dataType,
    required this.initialValue,
  });

  @override
  List<Object?> get props => [name, dataType, initialValue];

  // Metodi per la serializzazione/deserializzazione da/per JSON
  Map<String, dynamic> toJson() => {
    'name': name,
    'dataType': dataType,
    'initialValue': initialValue,
  };

  factory VariableDeclaration.fromJson(Map<String, dynamic> json) {
    return VariableDeclaration(
      name: json['name'],
      dataType: json['dataType'],
      initialValue: json['initialValue'],
    );
  }
}


/// Classe base astratta per tutti i nodi del diagramma di flusso.
abstract class FlowNode extends Equatable {
  final String id;
  final FlowNodeKind kind;
  final double x, y, width, height;
  final String text; // Etichetta visiva mostrata all'utente nel diagramma
  final Map<String, dynamic>? metadata; // Contenitore per dati futuri (es. breakpoint)

  const FlowNode({
    required this.id, required this.kind, required this.x, required this.y,
    required this.width, required this.height, required this.text, this.metadata,
  });

  /// Converte il modello di dominio in un'entità per la persistenza nel database.
  FlowNodeEntity toEntity();

  /// Factory che costruisce il corretto tipo di FlowNode a partire da un'entità del database.
  static FlowNode fromEntity(FlowNodeEntity entity) {
    switch (entity.kind) {
      case FlowNodeKind.start: return StartNode.fromEntity(entity);
      case FlowNodeKind.end: return EndNode.fromEntity(entity);
      case FlowNodeKind.process: return ProcessNode.fromEntity(entity);
      case FlowNodeKind.decision: return DecisionNode.fromEntity(entity);
      case FlowNodeKind.input: return InputNode.fromEntity(entity);
      case FlowNodeKind.output: return OutputNode.fromEntity(entity);
    }
  }

  @override
  List<Object?> get props => [id, kind, x, y, width, height, text, metadata];
}

// --- SOTTOCLASSI SPECIALIZZATE ---
class StartNode extends FlowNode {
  const StartNode({ required super.id, required super.x, required super.y, required super.width, required super.height, required super.text, super.metadata}) : super(kind: FlowNodeKind.start);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(id: id, kind: kind, x: x, y: y, width: width, height: height, text: text, metadata: metadata);
  static StartNode fromEntity(FlowNodeEntity e) => StartNode(id: e.id, x: e.x, y: e.y, width: e.width, height: e.height, text: e.text, metadata: e.metadata);

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
  const EndNode({ required super.id, required super.x, required super.y, required super.width, required super.height, required super.text, super.metadata}) : super(kind: FlowNodeKind.end);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(id: id, kind: kind, x: x, y: y, width: width, height: height, text: text, metadata: metadata);
  static EndNode fromEntity(FlowNodeEntity e) => EndNode(id: e.id, x: e.x, y: e.y, width: e.width, height: e.height, text: e.text, metadata: e.metadata);

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
  factory FunctionParam.fromJson(Map<String, dynamic> json) => FunctionParam(name: json['name'], type: json['type']);
  @override
  List<Object?> get props => [name, type];
}

class ProcessNode extends FlowNode {
  final String code; // stringa legacy / eventuale snippet o firma generata
  final String? functionName; // nuovo: nome funzione (derivato dal file)
  final String? returnType; // nuovo: tipo di ritorno
  final List<FunctionParam> params; // nuovi: parametri
  const ProcessNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.code = '',
    this.functionName,
    this.returnType,
    this.params = const [],
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
      'code': code,
      if (functionName != null) 'functionName': functionName,
      if (returnType != null) 'returnType': returnType,
      if (params.isNotEmpty) 'params': params.map((p) => p.toJson()).toList(),
    },
    metadata: metadata,
  );

  static ProcessNode fromEntity(FlowNodeEntity e) {
    final pRaw = e.data?['params'];
    return ProcessNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      code: e.data?['code'] ?? '',
      functionName: e.data?['functionName'],
      returnType: e.data?['returnType'],
      params: pRaw is List ? pRaw.map((d) => FunctionParam.fromJson(d)).toList() : const [],
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, code, functionName, returnType, params];

  ProcessNode copyWith({
    double? x,
    double? y,
    String? text,
    String? code,
    String? functionName,
    String? returnType,
    List<FunctionParam>? params,
  }) {
    return ProcessNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      code: code ?? this.code,
      functionName: functionName ?? this.functionName,
      returnType: returnType ?? this.returnType,
      params: params ?? this.params,
      metadata: metadata,
    );
  }
}

class DecisionNode extends FlowNode {
  final String condition;
  const DecisionNode({ required super.id, required super.x, required super.y, required super.width, required super.height, required super.text, this.condition = '', super.metadata}) : super(kind: FlowNodeKind.decision);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(id: id, kind: kind, x: x, y: y, width: width, height: height, text: text, data: {'condition': condition}, metadata: metadata);
  static DecisionNode fromEntity(FlowNodeEntity e) => DecisionNode(id: e.id, x: e.x, y: e.y, width: e.width, height: e.height, text: e.text, condition: e.data?['condition'] ?? '', metadata: e.metadata);
  @override
  List<Object?> get props => [...super.props, condition];

  DecisionNode copyWith({double? x, double? y, String? text, String? condition}) {
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
  const InputNode({ required super.id, required super.x, required super.y, required super.width, required super.height, required super.text, this.declarations = const [], super.metadata}) : super(kind: FlowNodeKind.input);

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(id: id, kind: kind, x: x, y: y, width: width, height: height, text: text, data: {'declarations': declarations.map((d) => d.toJson()).toList()}, metadata: metadata);
  static InputNode fromEntity(FlowNodeEntity e) {
    final declarationsData = e.data?['declarations'] as List<dynamic>? ?? [];
    return InputNode(id: e.id, x: e.x, y: e.y, width: e.width, height: e.height, text: e.text, declarations: declarationsData.map((d) => VariableDeclaration.fromJson(d)).toList(), metadata: e.metadata);
  }
  @override
  List<Object?> get props => [...super.props, declarations];

  InputNode copyWith({double? x, double? y, String? text, List<VariableDeclaration>? declarations}) {
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
  const OutputNode({ required super.id, required super.x, required super.y, required super.width, required super.height, required super.text, this.template = '', this.variables = const [], super.metadata}) : super(kind: FlowNodeKind.output);

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

  OutputNode copyWith({double? x, double? y, String? text, String? template, List<String>? variables}) {
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
  static FlowchartEdge fromEntity(EdgeEntity entity) => FlowchartEdge(from: entity.from, to: entity.to, port: entity.port);

  @override
  List<Object?> get props => [from, to, port];
}