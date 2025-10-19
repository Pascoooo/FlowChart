import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/src/entities/entities.dart';

/// Versione dello schema dati. Essenziale per gestire future migrazioni.
const int kFlowNodeSchemaVersion = 2;

/// Enum fortemente tipizzato per i tipi di nodi.
enum FlowNodeKind {
  start,
  end,
  process,
  decision,
  input,
  output,
  assignment,
  whileLoop,
  doWhileLoop,
  doWhileStart,
  functionHeader,  // Nodo intestazione sottoprogramma (non modificabile, solo in funzioni)
  returnNode       // Nodo di ritorno (solo in sottoprogrammi)
}

/// Enum per le categorie di variabili
enum VariableScope {
  input,
  output,
  local,
}

/// Rappresenta una singola clausola di condizione.
class ConditionClause extends Equatable {
  final String leftOperand;   // Nome della variabile a sinistra
  final String operator;       // Operatore: ==, !=, <, <=, >, >=, contains, !contains
  final String rightOperand;   // Nome della variabile o valore letterale a destra
  final bool isRightLiteral;   // true se rightOperand è un valore letterale, false se è una variabile

  const ConditionClause({
    required this.leftOperand,
    required this.operator,
    required this.rightOperand,
    this.isRightLiteral = false,
  });

  @override
  List<Object?> get props => [leftOperand, operator, rightOperand, isRightLiteral];

  ConditionClause copyWith({
    String? leftOperand,
    String? operator,
    String? rightOperand,
    bool? isRightLiteral,
  }) {
    return ConditionClause(
      leftOperand: leftOperand ?? this.leftOperand,
      operator: operator ?? this.operator,
      rightOperand: rightOperand ?? this.rightOperand,
      isRightLiteral: isRightLiteral ?? this.isRightLiteral,
    );
  }

  Map<String, dynamic> toMap() => {
    'leftOperand': leftOperand,
    'operator': operator,
    'rightOperand': rightOperand,
    'isRightLiteral': isRightLiteral,
  };

  factory ConditionClause.fromMap(Map<String, dynamic> map) {
    return ConditionClause(
      leftOperand: map['leftOperand'] ?? '',
      operator: map['operator'] ?? '==',
      rightOperand: map['rightOperand'] ?? '',
      isRightLiteral: map['isRightLiteral'] ?? false,
    );
  }

  /// Converte la clausola in una stringa leggibile per la generazione del codice
  String toExpression() {
    return '$leftOperand $operator $rightOperand';
  }
}

/// Rappresenta una singola dichiarazione di variabile.
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
      FlowNodeKind.input => InputNode.fromEntity(entity),
      FlowNodeKind.output => OutputNode.fromEntity(entity, allVariables),
      FlowNodeKind.assignment => AssignmentNode.fromEntity(entity),
      FlowNodeKind.whileLoop => WhileNode.fromEntity(entity),
      FlowNodeKind.doWhileLoop => DoWhileNode.fromEntity(entity),
      FlowNodeKind.functionHeader => FunctionHeaderNode.fromEntity(entity),
      FlowNodeKind.returnNode => ReturnNode.fromEntity(entity),
      FlowNodeKind.doWhileStart => throw UnsupportedError('FlowNodeKind.doWhileStart è un marcatore interno e non dovrebbe essere deserializzato'),
    };
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
  final List<ConditionClause> clauses;
  final String logicalJoin; // "AND" o "OR"

  const DecisionNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.clauses = const [],
    this.logicalJoin = 'AND',
    super.metadata,
  }) : super(kind: FlowNodeKind.decision);

  /// Genera la stringa della condizione completa per la visualizzazione
  String get condition {
    if (clauses.isEmpty) return '';

    if (clauses.length == 1) {
      return clauses.first.toExpression();
    }

    return clauses.map((c) => c.toExpression()).join(' $logicalJoin ');
  }

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
      'clauses': clauses.map((c) => c.toMap()).toList(),
      'logicalJoin': logicalJoin,
      // Manteniamo anche la stringa condition per retrocompatibilità
      'condition': condition,
    },
    metadata: metadata,
  );

  static DecisionNode fromEntity(FlowNodeEntity e) {
    // Supporto per nuovo formato con clausole
    final clausesData = e.data?['clauses'] as List?;

    List<ConditionClause> clauses = [];
    String logicalJoin = 'AND';

    if (clausesData != null && clausesData.isNotEmpty) {
      // Nuovo formato con clausole strutturate
      clauses = clausesData
          .map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
          .toList();
      logicalJoin = e.data?['logicalJoin'] ?? 'AND';
    } else {
      // Vecchio formato con stringa condition
      final legacyCondition = (e.data?['condition'] as String?)?.trim() ?? '';

      // Migrazione automatica della condizione legacy in clausole (parser semplice)
      if (legacyCondition.isNotEmpty) {
        // Determina il connettore principale (non gestisce parentesi annidate)
        if (legacyCondition.contains(' AND ')) {
          logicalJoin = 'AND';
        } else if (legacyCondition.contains(' OR ')) {
          logicalJoin = 'OR';
        }

        final parts = (logicalJoin == 'AND' && legacyCondition.contains(' AND '))
            ? legacyCondition.split(' AND ')
            : (logicalJoin == 'OR' && legacyCondition.contains(' OR '))
                ? legacyCondition.split(' OR ')
                : [legacyCondition];

        ConditionClause? _parseClause(String raw) {
          String s = raw.trim();
          while (s.startsWith('(') && s.endsWith(')')) {
            s = s.substring(1, s.length - 1).trim();
          }
          const ops = ['>=', '<=', '==', '!=', '>', '<', '='];
          String? op;
          for (final o in ops) {
            final idx = s.indexOf(' $o ');
            if (idx != -1) {
              op = o;
              break;
            }
          }
          if (op == null) return null;
          final split = s.split(' $op ');
          if (split.length != 2) return null;
          final left = split[0].trim();
          String right = split[1].trim();
          final normOp = (op == '=') ? '==' : op;
          bool isLiteral = false;
          if (right.isEmpty) {
            isLiteral = true;
          } else if (right.startsWith("'") && right.endsWith("'")) {
            isLiteral = true;
          } else if (right.startsWith('"') && right.endsWith('"')) {
            isLiteral = true;
          } else if (right.toLowerCase() == 'true' || right.toLowerCase() == 'false') {
            isLiteral = true;
          } else if (double.tryParse(right) != null) {
            isLiteral = true;
          }
          return ConditionClause(
            leftOperand: left,
            operator: normOp,
            rightOperand: right,
            isRightLiteral: isLiteral,
          );
        }

        final parsed = <ConditionClause>[];
        for (final p in parts) {
          final clause = _parseClause(p);
          if (clause != null) parsed.add(clause);
        }
        if (parsed.isNotEmpty) {
          clauses = parsed;
        }
      }
    }

    return DecisionNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      clauses: clauses,
      logicalJoin: logicalJoin,
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, clauses, logicalJoin];

  DecisionNode copyWith({
    double? x,
    double? y,
    String? text,
    List<ConditionClause>? clauses,
    String? logicalJoin,
  }) {
    return DecisionNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      clauses: clauses ?? this.clauses,
      logicalJoin: logicalJoin ?? this.logicalJoin,
      metadata: metadata,
    );
  }
}

/// Nodo per ciclo precondizionale (while)
class WhileNode extends FlowNode {
  final List<ConditionClause> clauses;
  final String logicalJoin;

  const WhileNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.clauses = const [],
    this.logicalJoin = 'AND',
    super.metadata,
  }) : super(kind: FlowNodeKind.whileLoop);

  String get condition {
    if (clauses.isEmpty) return '';
    if (clauses.length == 1) return clauses.first.toExpression();
    return clauses.map((c) => c.toExpression()).join(' $logicalJoin ');
  }

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
      'clauses': clauses.map((c) => c.toMap()).toList(),
      'logicalJoin': logicalJoin,
      'condition': condition,
    },
    metadata: metadata,
  );

  static WhileNode fromEntity(FlowNodeEntity e) {
    final clausesData = e.data?['clauses'] as List?;
    List<ConditionClause> clauses = [];
    String logicalJoin = 'AND';

    if (clausesData != null && clausesData.isNotEmpty) {
      clauses = clausesData
          .map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
          .toList();
      logicalJoin = e.data?['logicalJoin'] ?? 'AND';
    } else {
      // Supporto formato legacy con stringa 'condition'
      final legacyCondition = (e.data?['condition'] as String?)?.trim() ?? '';
      if (legacyCondition.isNotEmpty) {
        if (legacyCondition.contains(' AND ')) {
          logicalJoin = 'AND';
        } else if (legacyCondition.contains(' OR ')) {
          logicalJoin = 'OR';
        }
        final parts = (logicalJoin == 'AND' && legacyCondition.contains(' AND '))
            ? legacyCondition.split(' AND ')
            : (logicalJoin == 'OR' && legacyCondition.contains(' OR '))
                ? legacyCondition.split(' OR ')
                : [legacyCondition];

        ConditionClause? _parseClause(String raw) {
          String s = raw.trim();
          while (s.startsWith('(') && s.endsWith(')')) {
            s = s.substring(1, s.length - 1).trim();
          }
          const ops = ['>=', '<=', '==', '!=', '>', '<', '='];
          String? op;
          for (final o in ops) {
            final idx = s.indexOf(' $o ');
            if (idx != -1) { op = o; break; }
          }
          if (op == null) return null;
          final split = s.split(' $op ');
          if (split.length != 2) return null;
          final left = split[0].trim();
          String right = split[1].trim();
          final normOp = (op == '=') ? '==' : op;
          bool isLiteral = false;
          if (right.isEmpty) {
            isLiteral = true;
          } else if ((right.startsWith("'") && right.endsWith("'")) ||
                     (right.startsWith('"') && right.endsWith('"')) ||
                     right.toLowerCase() == 'true' || right.toLowerCase() == 'false' ||
                     double.tryParse(right) != null) {
            isLiteral = true;
          }
          return ConditionClause(
            leftOperand: left,
            operator: normOp,
            rightOperand: right,
            isRightLiteral: isLiteral,
          );
        }

        final parsed = <ConditionClause>[];
        for (final p in parts) {
          final clause = _parseClause(p);
          if (clause != null) parsed.add(clause);
        }
        if (parsed.isNotEmpty) {
          clauses = parsed;
        }
      }
    }

    return WhileNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      clauses: clauses,
      logicalJoin: logicalJoin,
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, clauses, logicalJoin];

  WhileNode copyWith({
    double? x,
    double? y,
    String? text,
    List<ConditionClause>? clauses,
    String? logicalJoin,
  }) {
    return WhileNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      clauses: clauses ?? this.clauses,
      logicalJoin: logicalJoin ?? this.logicalJoin,
      metadata: metadata,
    );
  }
}

/// Nodo per ciclo postcondizionale (do-while)
class DoWhileNode extends FlowNode {
  final List<ConditionClause> clauses;
  final String logicalJoin;

  const DoWhileNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.clauses = const [],
    this.logicalJoin = 'AND',
    super.metadata,
  }) : super(kind: FlowNodeKind.doWhileLoop);

  String get condition {
    if (clauses.isEmpty) return '';
    if (clauses.length == 1) return clauses.first.toExpression();
    return clauses.map((c) => c.toExpression()).join(' $logicalJoin ');
  }

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
      'clauses': clauses.map((c) => c.toMap()).toList(),
      'logicalJoin': logicalJoin,
      'condition': condition,
    },
    metadata: metadata,
  );

  static DoWhileNode fromEntity(FlowNodeEntity e) {
    final clausesData = e.data?['clauses'] as List?;
    List<ConditionClause> clauses = [];
    String logicalJoin = 'AND';

    if (clausesData != null && clausesData.isNotEmpty) {
      clauses = clausesData
          .map((c) => ConditionClause.fromMap(c as Map<String, dynamic>))
          .toList();
      logicalJoin = e.data?['logicalJoin'] ?? 'AND';
    }

    return DoWhileNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      clauses: clauses,
      logicalJoin: logicalJoin,
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, clauses, logicalJoin];

  DoWhileNode copyWith({
    double? x,
    double? y,
    String? text,
    List<ConditionClause>? clauses,
    String? logicalJoin,
  }) {
    return DoWhileNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      clauses: clauses ?? this.clauses,
      logicalJoin: logicalJoin ?? this.logicalJoin,
      metadata: metadata,
    );
  }
}

class InputNode extends FlowNode {
  final List<String> targetVariables;

  const InputNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.targetVariables = const [],
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
    data: {'targetVariables': targetVariables},
    metadata: metadata,
  );

  static InputNode fromEntity(FlowNodeEntity e) {
    final targetVariables = (e.data?['targetVariables'] as List?)?.cast<String>() ?? [];
    return InputNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      targetVariables: targetVariables,
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, targetVariables];

  InputNode copyWith({
    double? x,
    double? y,
    String? text,
    List<String>? targetVariables,
  }) {
    return InputNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      targetVariables: targetVariables ?? this.targetVariables,
      metadata: metadata,
    );
  }
}

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
  final String template;
  final List<VariableDeclaration> variables;

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
      'variables': variables.map((v) => v.name).toList(),
    },
    metadata: metadata,
  );

  static OutputNode fromEntity(
      FlowNodeEntity e, List<VariableDeclaration> allVariables) {
    final variableNames =
        (e.data?['variables'] as List?)?.cast<String>() ?? [];

    final resolvedVariables = variableNames
        .map((name) => allVariables.firstWhere(
          (v) => v.name == name,
      orElse: () => VariableDeclaration(name: name, dataType: 'unknown'),
    ))
        .toList();

    return OutputNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      template: e.data?['template'] ?? '',
      variables: resolvedVariables,
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, template, variables];

  OutputNode copyWith({
    double? x,
    double? y,
    String? text,
    String? template,
    List<VariableDeclaration>? variables,
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

/// Nodo di intestazione del sottoprogramma (non modificabile dall'utente)
/// Visualizza la firma della funzione: returnType functionName(params)
class FunctionHeaderNode extends FlowNode {
  final String functionName;
  final String returnType;
  final List<FunctionParam> parameters;

  const FunctionHeaderNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.functionName,
    required this.returnType,
    required this.parameters,
    super.metadata,
  }) : super(
    kind: FlowNodeKind.functionHeader,
    text: '', // Il testo viene generato automaticamente
  );

  /// Genera il testo della firma da visualizzare
  String get signatureText {
    final params = parameters.map((p) => '${p.type} ${p.name}').join(', ');
    return '$returnType $functionName($params)';
  }

  @override
  FlowNodeEntity toEntity() => FlowNodeEntity(
    id: id,
    kind: kind,
    x: x,
    y: y,
    width: width,
    height: height,
    text: signatureText,
    data: {
      'functionName': functionName,
      'returnType': returnType,
      'parameters': parameters.map((p) => p.toJson()).toList(),
    },
    metadata: metadata,
  );

  static FunctionHeaderNode fromEntity(FlowNodeEntity e) {
    final params = (e.data?['parameters'] as List?)
        ?.map((p) => FunctionParam.fromJson(p as Map<String, dynamic>))
        .toList() ?? [];

    return FunctionHeaderNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      functionName: e.data?['functionName'] ?? '',
      returnType: e.data?['returnType'] ?? 'void',
      parameters: params,
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, functionName, returnType, parameters];

  FunctionHeaderNode copyWith({
    double? x,
    double? y,
    String? functionName,
    String? returnType,
    List<FunctionParam>? parameters,
  }) {
    return FunctionHeaderNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      functionName: functionName ?? this.functionName,
      returnType: returnType ?? this.returnType,
      parameters: parameters ?? this.parameters,
      metadata: metadata,
    );
  }
}

/// Nodo di ritorno per sottoprogrammi
/// Per funzioni void: termina e restituisce il controllo
/// Per funzioni con valore: restituisce un'espressione/valore
class ReturnNode extends FlowNode {
  final String? returnExpression;

  const ReturnNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.text,
    this.returnExpression,
    super.metadata,
  }) : super(kind: FlowNodeKind.returnNode);

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
      if (returnExpression != null && returnExpression!.isNotEmpty)
        'returnExpression': returnExpression,
    },
    metadata: metadata,
  );

  static ReturnNode fromEntity(FlowNodeEntity e) {
    return ReturnNode(
      id: e.id,
      x: e.x,
      y: e.y,
      width: e.width,
      height: e.height,
      text: e.text,
      returnExpression: e.data?['returnExpression'],
      metadata: e.metadata,
    );
  }

  @override
  List<Object?> get props => [...super.props, returnExpression];

  ReturnNode copyWith({
    double? x,
    double? y,
    String? text,
    String? returnExpression,
  }) {
    return ReturnNode(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      text: text ?? this.text,
      returnExpression: returnExpression ?? this.returnExpression,
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
