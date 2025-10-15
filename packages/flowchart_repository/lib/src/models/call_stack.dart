import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/src/models/flowchart.dart';

import '../../flowchart_repository.dart'; // Make sure this import is correct

/// Represents a single frame in the call stack.
/// It holds all necessary information to manage the execution of a subprogram.
class CallStackFrame extends Equatable {
  final String flowchartId;
  final String flowchartName;
  final String? callerNodeId;  // ID of the calling ProcessNode
  final Map<String, dynamic> parameters;      // Parameters passed to the function
  final String returnType;
  final List<String> debugPath; // The debug path of the caller

  // ✨ This is the "snapshot" of the calling flowchart at the moment of the call.
  final Flowchart callerFlowchart;

  const CallStackFrame({
    required this.flowchartId,
    required this.flowchartName,
    this.callerNodeId,
    this.parameters = const {},
    this.returnType = 'void',
    this.debugPath = const [],
    required this.callerFlowchart, // This is now required
  });

  CallStackFrame copyWith({
    String? flowchartId,
    String? flowchartName,
    String? callerNodeId,
    Map<String, dynamic>? parameters,
    String? returnType,
    List<String>? debugPath,
    Flowchart? callerFlowchart,
  }) {
    return CallStackFrame(
      flowchartId: flowchartId ?? this.flowchartId,
      flowchartName: flowchartName ?? this.flowchartName,
      callerNodeId: callerNodeId ?? this.callerNodeId,
      parameters: parameters ?? this.parameters,
      returnType: returnType ?? this.returnType,
      debugPath: debugPath ?? this.debugPath,
      callerFlowchart: callerFlowchart ?? this.callerFlowchart,
    );
  }

  @override
  List<Object?> get props => [
    flowchartId,
    flowchartName,
    callerNodeId,
    parameters,
    returnType,
    debugPath,
    callerFlowchart, // Added to props for correct equality checks
  ];

  Map<String, dynamic> toJson() => {
    'flowchartId': flowchartId,
    'flowchartName': flowchartName,
    if (callerNodeId != null) 'callerNodeId': callerNodeId,
    'parameters': parameters,
    'returnType': returnType,
    'debugPath': debugPath,
    'callerFlowchart': callerFlowchart.toEntity().toDocument(), // Serialize the flowchart object
  };

  factory CallStackFrame.fromJson(Map<String, dynamic> json) {
    return CallStackFrame(
      flowchartId: json['flowchartId'],
      flowchartName: json['flowchartName'],
      callerNodeId: json['callerNodeId'],
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      returnType: json['returnType'] ?? 'void',
      debugPath: List<String>.from(json['debugPath'] ?? []),
      callerFlowchart: Flowchart.fromEntity(FlowchartEntity.fromDocument(json['callerFlowchart'])), // Deserialize the flowchart object
    );
  }
}

/// Represents the result of a subprogram call.
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

/// Manages the call stack for executing subprograms.
/// Supports nested calls and tracking the execution flow.
class CallStack extends Equatable {
  final List<CallStackFrame> frames;

  const CallStack({this.frames = const []});

  /// Returns the current frame (top of the stack).
  CallStackFrame? get current => frames.isEmpty ? null : frames.last;

  /// Returns the depth of the stack.
  int get depth => frames.length;

  /// Checks if the stack is empty.
  bool get isEmpty => frames.isEmpty;

  /// Adds a new frame to the stack (subprogram call).
  CallStack push(CallStackFrame frame) {
    return CallStack(frames: [...frames, frame]);
  }

  /// Removes the current frame from the stack (return from subprogram).
  CallStack pop() {
    if (frames.isEmpty) return this;
    return CallStack(frames: frames.sublist(0, frames.length - 1));
  }

  /// Returns the parameters of the current frame.
  Map<String, dynamic> get currentParameters {
    return current?.parameters ?? {};
  }

  /// Generates a textual representation of the stack for debugging.
  String toDebugString() {
    if (frames.isEmpty) return 'Call Stack: Empty';

    final buffer = StringBuffer('Call Stack (depth: $depth):\n');
    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final prefix = i == frames.length - 1 ? '→ ' : '  ';
      buffer.writeln('$prefix[$i] ${frame.flowchartName} (from ${frame.callerFlowchart.name})');

      if (frame.parameters.isNotEmpty) {
        buffer.writeln('    Parameters: ${frame.parameters}');
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