// Questo file non ha richiesto modifiche.

import 'package:flowchart_repository/flowchart_repository.dart';

/// Rappresenta un singolo nodo come viene salvato in Firestore.
class FlowNodeEntity {
  final String id;
  final FlowNodeKind kind;
  final double x, y, width, height;
  final String text;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? metadata;

  const FlowNodeEntity({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
    this.data,
    this.metadata,
  });

  Map<String, dynamic> toDocument() {
    return {
      'id': id,
      'kind': kind.toString().split('.').last,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'text': text,
      if (data != null && data!.isNotEmpty) 'data': data,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
    };
  }

  static FlowNodeEntity fromDocument(Map<String, dynamic> doc) {
    return FlowNodeEntity(
      id: doc['id'],
      kind: FlowNodeKind.values
          .firstWhere((k) => k.toString().split('.').last == doc['kind']),
      x: (doc['x'] as num).toDouble(),
      y: (doc['y'] as num).toDouble(),
      width: (doc['width'] as num).toDouble(),
      height: (doc['height'] as num).toDouble(),
      text: doc['text'],
      data: doc['data'] as Map<String, dynamic>?,
      metadata: doc['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Rappresenta una singola connessione come viene salvata in Firestore.
class EdgeEntity {
  final String from;
  final String to;
  final String? port;

  const EdgeEntity({required this.from, required this.to, required this.port});

  Map<String, dynamic> toDocument() {
    return {'from': from, 'to': to, if (port != null) 'port': port};
  }

  static EdgeEntity fromDocument(Map<String, dynamic> doc) {
    return EdgeEntity(from: doc['from'], to: doc['to'], port: doc['port']);
  }
}