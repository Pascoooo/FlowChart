// flow_node_factory.dart

import 'dart:ui';
import 'package:uuid/uuid.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

class FlowNodeFactory {
  static const _uuid = Uuid();

  static FlowNode createNode(
      FlowNodeKind kind,
      Offset position, {
        required List<VariableDeclaration> allVariables,
        Map<String, dynamic>? initialData,
      }) {
    final text =
        initialData?['text'] as String? ?? kind.toString().split('.').last;

    return switch (kind) {
      FlowNodeKind.start => StartNode(
        id: 'start_${_uuid.v4()}',
        x: position.dx,
        y: position.dy,
        width: 90.0,
        height: 90.0,
        text: 'Inizio',
      ),
      FlowNodeKind.end => EndNode(
        id: 'end_${_uuid.v4()}',
        x: position.dx,
        y: position.dy,
        width: 90.0,
        height: 90.0,
        text: 'Fine',
      ),
      FlowNodeKind.process => ProcessNode(
        id: _uuid.v4(),
        x: position.dx,
        y: position.dy,
        width: 150.0,
        height: 60.0,
        text: text,
        flowchartToCall: initialData?['flowchartToCall'] as String? ?? '',
        arguments:
        (initialData?['arguments'] as List?)?.cast<String>() ?? [],
        resultTarget: initialData?['resultTarget'] as String?,
      ),
      FlowNodeKind.decision => DecisionNode(
        id: _uuid.v4(),
        x: position.dx,
        y: position.dy,
        width: 120.0,
        height: 80.0,
        text: text,
        condition: initialData?['condition'] as String? ?? '',
      ),

    // CORRETTO: La logica ora si aspetta una semplice List<String> dal dialogo,
    // rendendo il codice più semplice e robusto.
      FlowNodeKind.input => InputNode(
        id: _uuid.v4(),
        x: position.dx,
        y: position.dy,
        width: 150.0,
        height: 60.0,
        text: text,
        targetVariables:
        (initialData?['targetVariables'] as List?)?.cast<String>() ?? [],
      ),

    // CORRETTO: La logica qui era già giusta. Legge i nomi delle variabili
    // e li "risolve" cercando l'oggetto completo nella lista globale.
      FlowNodeKind.output => () {
        final variableNames =
            (initialData?['variables'] as List?)?.cast<String>() ?? [];
        final resolvedVariables = variableNames
            .map((name) => allVariables.firstWhere(
              (v) => v.name == name,
          orElse: () =>
              VariableDeclaration(name: name, dataType: 'unknown'),
        ))
            .toList();

        return OutputNode(
          id: _uuid.v4(),
          x: position.dx,
          y: position.dy,
          width: 150.0,
          height: 60.0,
          text: text,
          template: initialData?['template'] as String? ?? '',
          variables: resolvedVariables,
        );
      }(),

      FlowNodeKind.assignment => AssignmentNode(
        id: _uuid.v4(),
        x: position.dx,
        y: position.dy,
        width: 150.0,
        height: 60.0,
        text: text,
        assignments: (initialData?['assignments'] as List?)
            ?.map((a) => Assignment.fromMap(a as Map<String, dynamic>))
            .toList() ??
            [],
      ),
    };
  }
}