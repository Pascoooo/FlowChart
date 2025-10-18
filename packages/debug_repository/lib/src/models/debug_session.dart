import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

/// Rappresenta una sessione di debug attiva
class DebugSession extends Equatable {
  final String sessionId;
  final String flowchartId;
  final Map<String, dynamic> variables;
  final List<String> debugPath;
  final int currentIndex;
  final CallStack callStack;
  final DateTime startedAt;

  const DebugSession({
    required this.sessionId,
    required this.flowchartId,
    required this.variables,
    required this.debugPath,
    required this.currentIndex,
    required this.callStack,
    required this.startedAt,
  });

  DebugSession copyWith({
    Map<String, dynamic>? variables,
    List<String>? debugPath,
    int? currentIndex,
    CallStack? callStack,
  }) {
    return DebugSession(
      sessionId: sessionId,
      flowchartId: flowchartId,
      variables: variables ?? this.variables,
      debugPath: debugPath ?? this.debugPath,
      currentIndex: currentIndex ?? this.currentIndex,
      callStack: callStack ?? this.callStack,
      startedAt: startedAt,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        flowchartId,
        variables,
        debugPath,
        currentIndex,
        callStack,
        startedAt,
      ];
}

