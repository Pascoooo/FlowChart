class ConnectionEntity {
  final String id;
  final String fromShapeId;
  final String toShapeId;

  ConnectionEntity({
    required this.id,
    required this.fromShapeId,
    required this.toShapeId,
  });

  /// Converte l'entità in un documento Map.
  Map<String, dynamic> toDocument() {
    return {
      'id': id,
      'fromShapeId': fromShapeId,
      'toShapeId': toShapeId,
    };
  }

  /// Crea un'entità da un documento Map.
  static ConnectionEntity fromDocument(Map<String, dynamic> doc) {
    return ConnectionEntity(
      id: doc['id'] as String,
      fromShapeId: doc['fromShapeId'] as String,
      toShapeId: doc['toShapeId'] as String,
    );
  }
}