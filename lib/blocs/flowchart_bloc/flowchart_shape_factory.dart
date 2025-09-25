import 'dart:ui';
import 'package:uuid/uuid.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

class FlowNodeFactory {
  static const _uuid = Uuid();

  static FlowNode createNode(
      FlowNodeKind kind,
      Offset position, {
        Map<String, dynamic>? initialData,
      }) {
    final text =
        initialData?['text'] as String? ?? kind.toString().split('.').last;

    switch (kind) {
      case FlowNodeKind.start:
        return StartNode(
          id: 'start_${_uuid.v4()}',
          x: position.dx,
          y: position.dy,
          width: 90.0,
          height: 90.0,
          text: 'Inizio',
        );

      case FlowNodeKind.end:
        return EndNode(
          id: 'end_${_uuid.v4()}',
          x: position.dx,
          y: position.dy,
          width: 90.0,
          height: 90.0,
          text: 'Fine',
        );

      case FlowNodeKind.process:
        final flowchartToCall =
            initialData?['flowchartToCall'] as String? ?? '';
        final arguments =
            (initialData?['arguments'] as List?)?.cast<String>() ?? [];
        final resultTarget = initialData?['resultTarget'] as String?;

        return ProcessNode(
          id: _uuid.v4(),
          x: position.dx,
          y: position.dy,
          width: 150.0,
          height: 60.0,
          text: text,
          flowchartToCall: flowchartToCall,
          arguments: arguments,
          resultTarget: resultTarget,
        );

      case FlowNodeKind.decision:
        final condition = initialData?['condition'] as String? ?? '';
        return DecisionNode(
          id: _uuid.v4(),
          x: position.dx,
          y: position.dy,
          width: 120.0,
          height: 80.0,
          text: text,
          condition: condition,
        );

      case FlowNodeKind.input:
      case FlowNodeKind.output:
        final declarations = (initialData?['declarations'] as List?)
            ?.map((d) => VariableDeclaration.fromJson(d))
            .toList() ?? [];
        final template = initialData?['template'] as String? ?? '';
        final variables =
            (initialData?['variables'] as List?)?.cast<String>() ?? [];

        if (kind == FlowNodeKind.input) {
          return InputNode(
            id: _uuid.v4(),
            x: position.dx, y: position.dy,
            // **CORREZIONE**: Dimensioni più compatte
            width: 150.0, height: 60.0,
            text: text,
            declarations: declarations,
          );
        } else {
          return OutputNode(
            id: _uuid.v4(),
            x: position.dx, y: position.dy,
            // **CORREZIONE**: Dimensioni più compatte
            width: 150.0, height: 60.0,
            text: text,
            template: template,
            variables: variables,
          );
        }
    }
  }
}