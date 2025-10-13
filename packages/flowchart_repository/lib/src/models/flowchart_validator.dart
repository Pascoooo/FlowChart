import 'package:flowchart_repository/flowchart_repository.dart';

/// Validatore per flowchart e sottoprogrammi
/// Verifica la correttezza strutturale secondo le regole definite
class SubprogramValidator {
  /// Valida un flowchart secondo il suo tipo (main o function)
  static SubprogramValidationResult validate(Flowchart flowchart) {
    final errors = <String>[];
    final warnings = <String>[];

    if (flowchart.isMain) {
      _validateMainFlowchart(flowchart, errors, warnings);
    } else if (flowchart.isFunction) {
      _validateFunctionFlowchart(flowchart, errors, warnings);
    }

    return SubprogramValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Valida un flowchart di tipo main
  static void _validateMainFlowchart(
    Flowchart flowchart,
    List<String> errors,
    List<String> warnings,
  ) {
    // Deve avere esattamente un nodo Start
    final startNodes = flowchart.nodes.whereType<StartNode>().toList();
    if (startNodes.isEmpty) {
      errors.add('Flowchart principale deve contenere un nodo Start');
    } else if (startNodes.length > 1) {
      errors.add('Flowchart principale deve contenere un solo nodo Start');
    }

    // Deve avere almeno un nodo End
    final endNodes = flowchart.nodes.whereType<EndNode>().toList();
    if (endNodes.isEmpty) {
      errors.add('Flowchart principale deve contenere almeno un nodo End');
    }

    // Non deve avere nodi FunctionHeader
    final headerNodes = flowchart.nodes.whereType<FunctionHeaderNode>().toList();
    if (headerNodes.isNotEmpty) {
      errors.add('Flowchart principale non deve contenere nodi FunctionHeader');
    }

    // Non deve avere nodi ReturnNode
    final returnNodes = flowchart.nodes.whereType<ReturnNode>().toList();
    if (returnNodes.isNotEmpty) {
      errors.add('Flowchart principale non deve contenere nodi Return');
    }
  }

  /// Valida un flowchart di tipo function (sottoprogramma)
  static void _validateFunctionFlowchart(
    Flowchart flowchart,
    List<String> errors,
    List<String> warnings,
  ) {
    // Non deve avere nodi Start
    final startNodes = flowchart.nodes.whereType<StartNode>().toList();
    if (startNodes.isNotEmpty) {
      errors.add('Sottoprogramma non deve contenere nodi Start');
    }

    // Non deve avere nodi End
    final endNodes = flowchart.nodes.whereType<EndNode>().toList();
    if (endNodes.isNotEmpty) {
      errors.add('Sottoprogramma non deve contenere nodi End');
    }

    // Deve avere esattamente un nodo FunctionHeader
    final headerNodes = flowchart.nodes.whereType<FunctionHeaderNode>().toList();
    if (headerNodes.isEmpty) {
      errors.add('Sottoprogramma deve contenere un nodo FunctionHeader');
    } else if (headerNodes.length > 1) {
      errors.add('Sottoprogramma deve contenere un solo nodo FunctionHeader');
    }

    // Verifica coerenza tra signature e FunctionHeader
    if (headerNodes.length == 1) {
      final header = headerNodes.first;
      if (header.returnType != flowchart.signature.returnType) {
        errors.add(
          'Il tipo di ritorno del FunctionHeader (${header.returnType}) '
          'non corrisponde alla signature (${flowchart.signature.returnType})',
        );
      }

      if (header.parameters.length != flowchart.signature.parameters.length) {
        errors.add(
          'Il numero di parametri del FunctionHeader (${header.parameters.length}) '
          'non corrisponde alla signature (${flowchart.signature.parameters.length})',
        );
      }
    }

    // Deve avere almeno un nodo Return
    final returnNodes = flowchart.nodes.whereType<ReturnNode>().toList();
    if (returnNodes.isEmpty) {
      warnings.add('Sottoprogramma dovrebbe contenere almeno un nodo Return');
    }

    // Verifica coerenza dei nodi Return con il tipo di ritorno
    final returnType = flowchart.signature.returnType;
    if (returnType != 'void') {
      // Funzioni con valore di ritorno devono avere espressioni di ritorno
      for (final returnNode in returnNodes) {
        if (returnNode.returnExpression == null ||
            returnNode.returnExpression!.trim().isEmpty) {
          warnings.add(
            'Nodo Return ${returnNode.id} dovrebbe contenere un\'espressione '
            'di ritorno per il tipo $returnType',
          );
        }
      }
    } else {
      // Funzioni void non dovrebbero avere espressioni di ritorno
      for (final returnNode in returnNodes) {
        if (returnNode.returnExpression != null &&
            returnNode.returnExpression!.trim().isNotEmpty) {
          warnings.add(
            'Nodo Return ${returnNode.id} non dovrebbe contenere un\'espressione '
            'di ritorno per funzioni void',
          );
        }
      }
    }
  }

  /// Valida una chiamata a sottoprogramma
  static SubprogramValidationResult validateFunctionCall({
    required ProcessNode callNode,
    required Flowchart callerFlowchart,
    required Flowchart? calleeFlowchart,
    required List<Flowchart> allFlowcharts,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Verifica che il flowchart chiamato esista
    if (calleeFlowchart == null) {
      errors.add(
        'Sottoprogramma "${callNode.flowchartToCall}" non trovato',
      );
      return SubprogramValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    // Verifica che il flowchart chiamato sia una funzione
    if (!calleeFlowchart.isFunction) {
      errors.add(
        'Impossibile chiamare "${calleeFlowchart.name}" perché non è un sottoprogramma',
      );
    }

    // Verifica numero di argomenti
    final expectedParams = calleeFlowchart.signature.parameters.length;
    final providedArgs = callNode.arguments.length;

    if (providedArgs != expectedParams) {
      errors.add(
        'Numero di argomenti errato per "${calleeFlowchart.name}": '
        'attesi $expectedParams, forniti $providedArgs',
      );
    }

    // Verifica che resultTarget sia specificato per funzioni con valore di ritorno
    final returnType = calleeFlowchart.signature.returnType;
    if (returnType != 'void') {
      if (callNode.resultTarget == null || callNode.resultTarget!.trim().isEmpty) {
        warnings.add(
          'La chiamata a "${calleeFlowchart.name}" restituisce un valore di tipo $returnType '
          'ma non è specificata una variabile target',
        );
      }
    } else {
      if (callNode.resultTarget != null && callNode.resultTarget!.trim().isNotEmpty) {
        warnings.add(
          'La chiamata a "${calleeFlowchart.name}" è void ma è specificata '
          'una variabile target "${callNode.resultTarget}"',
        );
      }
    }

    return SubprogramValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// Risultato di una validazione di sottoprogrammi
class SubprogramValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const SubprogramValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    final buffer = StringBuffer();

    if (isValid && !hasWarnings) {
      buffer.writeln('✓ Validazione superata');
    } else {
      if (hasErrors) {
        buffer.writeln('✗ Errori di validazione:');
        for (final error in errors) {
          buffer.writeln('  - $error');
        }
      }

      if (hasWarnings) {
        buffer.writeln('⚠ Avvertimenti:');
        for (final warning in warnings) {
          buffer.writeln('  - $warning');
        }
      }
    }

    return buffer.toString();
  }
}
