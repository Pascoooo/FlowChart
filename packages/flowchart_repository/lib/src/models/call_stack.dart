import 'package:equatable/equatable.dart';

/// Rappresenta un singolo frame nello stack di chiamate
/// Contiene tutte le informazioni necessarie per gestire l'esecuzione di un sottoprogramma
class CallStackFrame extends Equatable {
  final String flowchartId;
  final String flowchartName;
  final String? callerNodeId;  // ID del nodo ProcessNode chiamante
  final Map<String, dynamic> localVariables;  // Variabili locali del sottoprogramma
  final Map<String, dynamic> parameters;      // Parametri passati alla funzione
  final String returnType;

  const CallStackFrame({
    required this.flowchartId,
    required this.flowchartName,
    this.callerNodeId,
    this.localVariables = const {},
    this.parameters = const {},
    this.returnType = 'void',
  });

  CallStackFrame copyWith({
    String? flowchartId,
    String? flowchartName,
    String? callerNodeId,
    Map<String, dynamic>? localVariables,
    Map<String, dynamic>? parameters,
    String? returnType,
  }) {
    return CallStackFrame(
      flowchartId: flowchartId ?? this.flowchartId,
      flowchartName: flowchartName ?? this.flowchartName,
      callerNodeId: callerNodeId ?? this.callerNodeId,
      localVariables: localVariables ?? this.localVariables,
      parameters: parameters ?? this.parameters,
      returnType: returnType ?? this.returnType,
    );
  }

  @override
  List<Object?> get props => [
        flowchartId,
        flowchartName,
        callerNodeId,
        localVariables,
        parameters,
        returnType,
      ];

  Map<String, dynamic> toJson() => {
        'flowchartId': flowchartId,
        'flowchartName': flowchartName,
        if (callerNodeId != null) 'callerNodeId': callerNodeId,
        'localVariables': localVariables,
        'parameters': parameters,
        'returnType': returnType,
      };

  factory CallStackFrame.fromJson(Map<String, dynamic> json) {
    return CallStackFrame(
      flowchartId: json['flowchartId'],
      flowchartName: json['flowchartName'],
      callerNodeId: json['callerNodeId'],
      localVariables: json['localVariables'] ?? {},
      parameters: json['parameters'] ?? {},
      returnType: json['returnType'] ?? 'void',
    );
  }
}

/// Rappresenta il risultato di una chiamata a un sottoprogramma
class FunctionCallResult extends Equatable {
  final dynamic returnValue;
  final bool hasValue;

  const FunctionCallResult({
    this.returnValue,
    this.hasValue = false,
  });

  const FunctionCallResult.void_() : returnValue = null, hasValue = false;

  FunctionCallResult.withValue(dynamic value)
      : returnValue = value,
        hasValue = true;

  @override
  List<Object?> get props => [returnValue, hasValue];
}

/// Gestisce lo stack di chiamate per l'esecuzione di sottoprogrammi
/// Supporta chiamate annidate e tracciamento del flusso di esecuzione
class CallStack extends Equatable {
  final List<CallStackFrame> frames;

  const CallStack({this.frames = const []});

  /// Restituisce il frame corrente (top dello stack)
  CallStackFrame? get current => frames.isEmpty ? null : frames.last;

  /// Restituisce la profondità dello stack
  int get depth => frames.length;

  /// Verifica se lo stack è vuoto
  bool get isEmpty => frames.isEmpty;

  /// Verifica se siamo nel main (stack vuoto o solo main frame)
  bool get isInMain => frames.isEmpty || frames.length == 1;

  /// Aggiunge un nuovo frame allo stack (chiamata a sottoprogramma)
  CallStack push(CallStackFrame frame) {
    return CallStack(frames: [...frames, frame]);
  }

  /// Rimuove il frame corrente dallo stack (ritorno da sottoprogramma)
  CallStack pop() {
    if (frames.isEmpty) return this;
    return CallStack(frames: frames.sublist(0, frames.length - 1));
  }

  /// Aggiorna le variabili locali del frame corrente
  CallStack updateCurrentVariables(Map<String, dynamic> variables) {
    if (frames.isEmpty) return this;

    final updatedFrames = List<CallStackFrame>.from(frames);
    updatedFrames[frames.length - 1] = frames.last.copyWith(
      localVariables: {...frames.last.localVariables, ...variables},
    );

    return CallStack(frames: updatedFrames);
  }

  /// Restituisce le variabili locali del frame corrente
  Map<String, dynamic> get currentVariables {
    return current?.localVariables ?? {};
  }

  /// Restituisce i parametri del frame corrente
  Map<String, dynamic> get currentParameters {
    return current?.parameters ?? {};
  }

  /// Genera una rappresentazione testuale dello stack per il debug
  String toDebugString() {
    if (frames.isEmpty) return 'Call Stack: Empty';

    final buffer = StringBuffer('Call Stack (depth: $depth):\n');
    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final prefix = i == frames.length - 1 ? '→ ' : '  ';
      buffer.writeln('$prefix[$i] ${frame.flowchartName} (${frame.flowchartId})');

      if (frame.parameters.isNotEmpty) {
        buffer.writeln('    Parameters: ${frame.parameters}');
      }
      if (frame.localVariables.isNotEmpty) {
        buffer.writeln('    Locals: ${frame.localVariables}');
      }
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [frames];

  Map<String, dynamic> toJson() => {
        'frames': frames.map((f) => f.toJson()).toList(),
      };

  factory CallStack.fromJson(Map<String, dynamic> json) {
    final framesList = json['frames'] as List<dynamic>? ?? [];
    return CallStack(
      frames: framesList
          .map((f) => CallStackFrame.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}

