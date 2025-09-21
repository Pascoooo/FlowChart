// models/shape.dart (COMPLETO E MODIFICATO)

import '../../src/entities/shape_entity.dart';

class Shape {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String text;

  // --- NUOVE PROPRIETÀ ---
  /// Lista degli ID delle connessioni in entrata.
  final List<String> incomingConnectionIds;
  /// Lista degli ID delle connessioni in uscita.
  final List<String> outgoingConnectionIds;

  const Shape({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
    // Inizializziamo le nuove liste (default a vuote)
    this.incomingConnectionIds = const [],
    this.outgoingConnectionIds = const [],
  });

  // --- NUOVI METODI DI SUPPORTO PER LA UI ---

  /// Ritorna il numero massimo di connessioni in uscita per questo tipo di forma.
  int get maxOutgoingConnections {
    switch (type) {
      case 'decision':
        return 2;
      case 'end':
        return 0;
      default:
        return 1;
    }
  }

  /// Ritorna il numero massimo di connessioni in entrata per questo tipo di forma.
  int get maxIncomingConnections {
    switch (type) {
      case 'start':
        return 0;
      default:
        return 1;
    }
  }

  /// La UI userà questo per decidere se mostrare il pulsante "+".
  /// La logica è ora incapsulata direttamente nel modello!
  bool get canAddOutgoingConnection => outgoingConnectionIds.length < maxOutgoingConnections;

  // ---------------------------------------------

  ShapeEntity toEntity() {
    return ShapeEntity(
      id: id,
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      text: text,
      // Nota: Non salviamo le connessioni qui, perché sono già nel modello Flowchart.
      // Le ricostruiremo al momento del caricamento.
    );
  }

  static Shape fromEntity(ShapeEntity entity) {
    return Shape(
      id: entity.id,
      type: entity.type,
      x: entity.x,
      y: entity.y,
      width: entity.width,
      height: entity.height,
      text: entity.text,
    );
  }

  /// Metodo "copyWith" per aggiornare facilmente l'oggetto in modo immutabile.
  Shape copyWith({
    List<String>? incomingConnectionIds,
    List<String>? outgoingConnectionIds,
  }) {
    return Shape(
      id: id,
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      text: text,
      incomingConnectionIds: incomingConnectionIds ?? this.incomingConnectionIds,
      outgoingConnectionIds: outgoingConnectionIds ?? this.outgoingConnectionIds,
    );
  }
}