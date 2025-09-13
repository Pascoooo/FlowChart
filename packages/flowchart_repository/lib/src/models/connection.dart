import '../../src/entities/connection_entity.dart';

class Connection {
  final String id;
  final String fromShapeId;
  final String toShapeId;

  const Connection({
    required this.id,
    required this.fromShapeId,
    required this.toShapeId,
  });

  /// Converte il modello [Connection] in una [ConnectionEntity].
  ConnectionEntity toEntity() {
    return ConnectionEntity(
      id: id,
      fromShapeId: fromShapeId,
      toShapeId: toShapeId,
    );
  }

  /// Crea un modello [Connection] da una [ConnectionEntity].
  static Connection fromEntity(ConnectionEntity entity) {
    return Connection(
      id: entity.id,
      fromShapeId: entity.fromShapeId,
      toShapeId: entity.toShapeId,
    );
  }
}