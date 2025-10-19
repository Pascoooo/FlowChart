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

  // 🔴 FIX CRITICO #2: Comunicazione esplicita dello stato del percorso
  final bool isEndOfPath;  // Il percorso è terminato (End node raggiunto)
  final String? decisionBranch;  // 'true', 'false', 'loop', null se non è una decisione

  // 🟠 FIX MAGGIORE #4: Supporto per sottoprogrammi
  final bool isSubprogramCall;  // Questo nodo chiama un sottoprogramma
  final String? subprogramName;  // Nome del sottoprogramma da chiamare

  // 🆕 Classificazione errore: bloccante vs non-bloccante
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
