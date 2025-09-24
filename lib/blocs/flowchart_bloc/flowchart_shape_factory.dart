import 'dart:ui';
import 'package:uuid/uuid.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

class FlowNodeFactory {
  static const _uuid = Uuid();

  static FlowNode createNode(
      FlowNodeKind kind,
      Offset position, {
        Map<String, dynamic>? initialData, // Nuovo parametro opzionale
      }) {
    // Estrai i dati comuni o usa valori di default
    final text = initialData?['text'] as String? ?? kind.toString().split('.').last;
    final code = initialData?['code'] as String? ?? '';
    final condition = initialData?['condition'] as String? ?? '';
    final template = initialData?['template'] as String? ?? '';
    final declarations = (initialData?['declarations'] as List?)
        ?.map((d) => VariableDeclaration.fromJson(d))
        .toList() ?? [];
    final variables = (initialData?['variables'] as List?)
        ?.map((v) => v.toString())
        .toList() ?? [];

    // Dati specifici per il nodo di processo (nuovo dialog)
    final functionName = initialData?['functionName'] as String?; // opzionale
    final returnType = initialData?['returnType'] as String?; // opzionale
    final paramsRaw = initialData?['params'];
    final params = paramsRaw is List
        ? paramsRaw
            .whereType<Map>()
            .map((m) => FunctionParam.fromJson(m.cast<String, dynamic>()))
            .toList()
        : <FunctionParam>[];

    switch (kind) {
      case FlowNodeKind.start:
        return StartNode(
          id: 'start_${_uuid.v4()}',
          x: position.dx, y: position.dy,
          width: 90.0, height: 90.0,
          text: 'Inizio',
        );

      case FlowNodeKind.end:
        return EndNode(
          id: 'end_${_uuid.v4()}',
          x: position.dx, y: position.dy,
          width: 90.0, height: 90.0,
          text: 'Fine',
        );

      case FlowNodeKind.process:
        return ProcessNode(
          id: _uuid.v4(),
          x: position.dx, y: position.dy,
          width: 150.0, height: 60.0,
          text: text,
          code: code,
          functionName: functionName,
          returnType: returnType,
          params: params,
        );

      case FlowNodeKind.decision:
        return DecisionNode(
          id: _uuid.v4(),
          x: position.dx, y: position.dy,
          width: 120.0, height: 80.0,
          text: text,
          condition: condition, // Usa i dati dal dialogo
        );

      case FlowNodeKind.input:
        return InputNode(
          id: _uuid.v4(),
          x: position.dx, y: position.dy,
          width: 130.0, height: 60.0,
          text: text,
          declarations: declarations, // Usa i dati dal dialogo
        );

      case FlowNodeKind.output:
        return OutputNode(
          id: _uuid.v4(),
          x: position.dx, y: position.dy,
          width: 130.0, height: 60.0,
          text: text,
          template: template, // Usa i dati dal dialogo
          variables: variables,
        );
    }
  }
}