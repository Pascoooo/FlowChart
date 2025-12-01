import 'package:equatable/equatable.dart';

/// Risultato dell'esecuzione di un nodo
class ExecutionResult extends Equatable {
  final bool success;
  final String? errorMessage;
  final String? outputMessage;
  final Map<String, dynamic> updatedVariables;
  final dynamic returnValue;
  final bool hasReturnValue;
  final bool requiresUserInput;
  final String? userInputPrompt;

  /// Indica se il percorso di esecuzione è terminato (End node raggiunto)
  final bool isEndOfPath;

  /// Specifica il branch di decisione preso: 'true', 'false', 'loop', o null
  final String? decisionBranch;

  /// Indica se questo nodo esegue una chiamata a un sottoprogramma
  final bool isSubprogramCall;

  /// Nome del sottoprogramma da invocare (se isSubprogramCall è true)
  final String? subprogramName;

  /// Classifica l'errore come bloccante (true) o non-bloccante (false)
  final bool isBlockingError;

  const ExecutionResult({
    required this.success,
    this.errorMessage,
    this.outputMessage,
    this.updatedVariables = const {},
    this.returnValue,
    this.hasReturnValue = false,
    this.requiresUserInput = false,
    this.userInputPrompt,
    this.isEndOfPath = false,
    this.decisionBranch,
    this.isSubprogramCall = false,
    this.subprogramName,
    this.isBlockingError = true,
  });

  factory ExecutionResult.success({
    String? message,
    Map<String, dynamic>? updatedVariables,
    String? decisionBranch,
  }) {
    return ExecutionResult(
      success: true,
      outputMessage: message,
      updatedVariables: updatedVariables ?? {},
      decisionBranch: decisionBranch,
    );
  }

  factory ExecutionResult.error(String message, {bool blocking = true}) {
    return ExecutionResult(
      success: false,
      errorMessage: message,
      isBlockingError: blocking,
    );
  }

  factory ExecutionResult.withReturn(dynamic value) {
    return ExecutionResult(
      success: true,
      returnValue: value,
      hasReturnValue: true,
    );
  }

  factory ExecutionResult.requiresInput(String prompt) {
    return ExecutionResult(
      success: true,
      requiresUserInput: true,
      userInputPrompt: prompt,
    );
  }

  factory ExecutionResult.endOfPath({String? message}) {
    return ExecutionResult(
      success: true,
      isEndOfPath: true,
      outputMessage: message ?? 'Fine percorso',
    );
  }

  factory ExecutionResult.subprogramCall(String subprogramName) {
    return ExecutionResult(
      success: true,
      isSubprogramCall: true,
      subprogramName: subprogramName,
      outputMessage: 'Chiamata a $subprogramName',
    );
  }

  @override
  List<Object?> get props => [
        success,
        errorMessage,
        outputMessage,
        updatedVariables,
        returnValue,
        hasReturnValue,
        requiresUserInput,
        userInputPrompt,
        isEndOfPath,
        decisionBranch,
        isSubprogramCall,
        subprogramName,
        isBlockingError,
      ];
}
